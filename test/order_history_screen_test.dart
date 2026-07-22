import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _FetchCall {
  const _FetchCall({required this.tab, required this.range});

  final OrderHistoryTab tab;
  final OrderDateRange range;
}

class _FakeRepo implements OrderRepository {
  _FakeRepo(this._orders);

  final Map<OrderHistoryTab, List<OrderSummary>> _orders;
  final List<_FetchCall> calls = [];

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    calls.add(_FetchCall(tab: tab, range: range));
    final matching = (_orders[tab] ?? const <OrderSummary>[])
        .where((order) => _isWithinRange(order.createdAt, range))
        .toList(growable: false);
    final start = (page - 1) * pageSize;
    if (start >= matching.length) {
      return OrderPage(items: const [], page: page, hasMore: false);
    }
    final end = (start + pageSize).clamp(0, matching.length);
    return OrderPage(
      items: matching.sublist(start, end),
      page: page,
      hasMore: end < matching.length,
    );
  }

  static bool _isWithinRange(DateTime createdAt, OrderDateRange range) {
    final from = range.from;
    final to = range.to;
    return (from == null || !createdAt.isBefore(from)) &&
        (to == null || createdAt.isBefore(to));
  }
}

OrderSummary _o(String id, OrderRequestStatus status, {DateTime? createdAt}) =>
    OrderSummary(
      id: id,
      createdAt: createdAt ?? DateTime.utc(2026, 5, 17, 10),
      pickupAddress: 'Pickup $id',
      dropoffAddress: 'Dropoff $id',
      status: status,
      tier: OrderTier.express,
      amountMinor: 1234_00,
      currency: 'USD',
    );

Widget _host(
  OrderRepository repo, {
  RoleCubit? roleCubit,
  double textScaleFactor = 1,
  int pageSize = 2,
}) {
  final cubit = OrderHistoryCubit(repository: repo, pageSize: pageSize);
  Widget screen = BlocProvider.value(
    value: cubit,
    child: const Scaffold(body: OrderHistoryScreen()),
  );
  // BUG-A: the Delivery tab is shared; when acting as a jeeber the row tap must
  // reach the jeeber active-delivery (progression) screen, not the customer
  // detail. Supply a RoleCubit ancestor so the screen can read the active role.
  final role = roleCubit;
  if (role != null) {
    screen = BlocProvider<RoleCubit>.value(value: role, child: screen);
  }
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            Scaffold(body: Text('detail-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/jeeber/deliveries/:id/active',
        builder: (_, state) =>
            Scaffold(body: Text('jeeber-active-${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final scaled = MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScaleFactor));
      return MediaQuery(
        data: scaled,
        child: Builder(
          builder: (scaledContext) => jeebA11yBuilder(scaledContext, child),
        ),
      );
    },
  );
}

void main() {
  testWidgets('renders the three tabs', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('loads the first page of active orders on mount', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [
        _o('a1', OrderRequestStatus.enRoute),
        _o('a2', OrderRequestStatus.pickedUp),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-history-card-a1')), findsOneWidget);
    expect(find.byKey(const Key('order-history-card-a2')), findsOneWidget);
  });

  testWidgets('shows the per-tab empty state when the active list is empty', (
    tester,
  ) async {
    final repo = _FakeRepo(const {});
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-history-empty-active')), findsOneWidget);
  });

  testWidgets('tapping a card navigates to /orders/:id', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [_o('xyz', OrderRequestStatus.enRoute)],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-history-card-xyz')));
    await tester.pumpAndSettle();

    expect(find.text('detail-xyz'), findsOneWidget);
  });

  testWidgets(
    'BUG-A: acting as a jeeber, tapping a card navigates to the jeeber '
    'active-delivery (progression) screen, not the customer detail',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final roleCubit = RoleCubit(prefs: prefs, initialRole: UserRole.jeeber);
      addTearDown(roleCubit.close);

      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('job7', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(_host(repo, roleCubit: roleCubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('order-history-card-job7')));
      await tester.pumpAndSettle();

      expect(find.text('jeeber-active-job7'), findsOneWidget);
      expect(find.text('detail-job7'), findsNothing);
    },
  );

  for (final textScaleFactor in <double>[1, 2]) {
    testWidgets(
      'date filter selects, applies, and clears at ${textScaleFactor}x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final selectedDate = DateTime.now();
        final expectedDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        final expectedExclusiveEnd = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day + 1,
        );
        final sameDayOrder = _o(
          'same-day',
          OrderRequestStatus.enRoute,
          createdAt: DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            12,
          ),
        );
        final previousDayOrder = _o(
          'previous-day',
          OrderRequestStatus.enRoute,
          createdAt: DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day - 1,
            12,
          ),
        );
        final exclusiveEndOrder = _o(
          'exclusive-end',
          OrderRequestStatus.enRoute,
          createdAt: expectedExclusiveEnd,
        );
        final repo = _FakeRepo({
          OrderHistoryTab.active: [
            sameDayOrder,
            previousDayOrder,
            exclusiveEndOrder,
          ],
        });
        await tester.pumpWidget(
          _host(repo, textScaleFactor: textScaleFactor, pageSize: 20),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('order-history-card-same-day')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('order-history-card-previous-day')),
          findsOneWidget,
        );
        await tester.tap(
          find.bySemanticsIdentifier('order_history_filter_chip'),
        );
        await tester.pumpAndSettle();

        await _pickDate(
          tester,
          pickerIdentifier: 'order_history_sheet_from_cta',
          day: selectedDate.day,
        );
        await _pickDate(
          tester,
          pickerIdentifier: 'order_history_sheet_to_cta',
          day: selectedDate.day,
        );

        final apply = find.byKey(const Key('order-history-filter-apply'));
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();

        expect(repo.calls.last.range.from, expectedDate);
        expect(repo.calls.last.range.to, expectedExclusiveEnd);
        expect(
          find.byKey(const Key('order-history-card-same-day')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('order-history-card-previous-day')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('order-history-card-exclusive-end')),
          findsNothing,
        );

        await tester.tap(
          find.bySemanticsIdentifier('order_history_filter_chip'),
        );
        await tester.pumpAndSettle();
        final clear = find.byKey(const Key('order-history-filter-clear'));
        await tester.ensureVisible(clear);
        await tester.tap(clear);
        await tester.pumpAndSettle();

        expect(repo.calls.last.range, const OrderDateRange());
        expect(
          find.byKey(const Key('order-history-card-same-day')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('order-history-card-previous-day')),
          findsOneWidget,
        );
        final exclusiveEndCard = find.byKey(
          const Key('order-history-card-exclusive-end'),
        );
        await tester.scrollUntilVisible(
          exclusiveEndCard,
          200,
          scrollable: find.descendant(
            of: find.byKey(const Key('order-history-list-active')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(exclusiveEndCard, findsOneWidget);
      },
    );
  }
}

Future<void> _pickDate(
  WidgetTester tester, {
  required String pickerIdentifier,
  required int day,
}) async {
  await tester.tap(find.bySemanticsIdentifier(pickerIdentifier));
  await tester.pumpAndSettle();

  expect(find.byType(DatePickerDialog), findsOneWidget);
  final dayCell = find.text('$day');
  expect(dayCell, findsOneWidget);
  await tester.tap(dayCell);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
