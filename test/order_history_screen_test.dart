import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
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

/// Mirrors the non-linear-capable [SystemTextScaler] supplied by Android.
/// Even at the S24's 1.0 system font scale this must not be replaced by
/// [TextScaler.linear]: the linear implementation optimizes app-level clamps
class _DeviceTextScaler extends TextScaler {
  const _DeviceTextScaler(this.textScaleFactor);

  @override
  final double textScaleFactor;

  @override
  double scale(double fontSize) => fontSize * textScaleFactor;
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

class _ThrowingRepo implements OrderRepository {
  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async =>
      throw const OrderRepositoryException(OrderRepositoryErrorKind.server);
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
  TextScaler? textScaler,
  int pageSize = 2,
  Locale locale = const Locale('en'),
  OrderHistoryTab initialTab = OrderHistoryTab.active,
}) {
  final cubit = OrderHistoryCubit(repository: repo, pageSize: pageSize);
  Widget screen = BlocProvider.value(
    value: cubit,
    child: Scaffold(body: OrderHistoryScreen(initialTab: initialTab)),
  );
  // BUG-A: the Delivery tab is shared; when acting as a jeeber the row tap must
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
      // The create-flow entry every sibling surface uses; the redesigned
      // "Jeeb it again" row CTA enters it unseeded.
      GoRoute(
        path: '/request-type',
        name: 'request-type',
        builder: (_, _) => const Scaffold(body: Text('request-type-screen')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      // MIDNIGHT: E4's illustration loops ∞ by design, so `pumpAndSettle`
      // cannot settle on any empty/loading/error frame without reduce motion.
      final scaled = MediaQuery.of(context).copyWith(
        textScaler: textScaler ?? TextScaler.linear(textScaleFactor),
        disableAnimations: true,
      );
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
  testWidgets(
    'S24 regression: From opens DatePickerDialog with the device 1.0 scaler',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('s24-order', OrderRequestStatus.enRoute)],
      });
      final installedRouteScaler = const _DeviceTextScaler(
        1,
      ).clamp(minScaleFactor: 1, maxScaleFactor: A11y.maxTextScaleFactor);
      await tester.pumpWidget(_host(repo, textScaler: installedRouteScaler));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('order_history_filter_chip'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('order_history_sheet_from_cta'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

  group('redesign-24 header, tab pills and row CTAs', () {
    testWidgets('the board title band renders above the tab pills', (
      tester,
    ) async {
      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('Delivery'), findsOneWidget);
      final titleY = tester.getTopLeft(find.text('Delivery')).dy;
      final tabY = tester.getTopLeft(find.text('Active')).dy;
      expect(titleY, lessThan(tabY));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a partially loaded tab shows NO count (hasMore is the gate)', (
      tester,
    ) async {
      final repo = _FakeRepo({
        OrderHistoryTab.active: [
          _o('a1', OrderRequestStatus.enRoute),
          _o('a2', OrderRequestStatus.enRoute),
          _o('a3', OrderRequestStatus.enRoute),
        ],
      });
      // pageSize 2 of 3 rows -> hasMore stays true.
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      // A loaded-lower-bound count would be a lie, so no digit is drawn.
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('a fully loaded tab shows its true count', (tester) async {
      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(_host(repo, pageSize: 20));
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('tapping a tab pill switches the list', (tester) async {
      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
        OrderHistoryTab.completed: [_o('c1', OrderRequestStatus.delivered)],
      });
      await tester.pumpWidget(_host(repo, pageSize: 20));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('order_history_completed_tab'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order-history-card-c1')), findsOneWidget);
    });

    testWidgets('Track lands on the customer detail surface', (tester) async {
      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('t1', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(_host(repo, pageSize: 20));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('order_history_track_cta_t1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('detail-t1'), findsOneWidget);
    });

    testWidgets(
      'BUG-A holds for Track too: a jeeber reaches the progression screen',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final roleCubit = RoleCubit(prefs: prefs, initialRole: UserRole.jeeber);
        addTearDown(roleCubit.close);

        final repo = _FakeRepo({
          OrderHistoryTab.active: [_o('job9', OrderRequestStatus.enRoute)],
        });
        await tester.pumpWidget(
          _host(repo, roleCubit: roleCubit, pageSize: 20),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsIdentifier('order_history_track_cta_job9'),
        );
        await tester.pumpAndSettle();

        expect(find.text('jeeber-active-job9'), findsOneWidget);
        expect(find.text('detail-job9'), findsNothing);
      },
    );

    testWidgets('"Jeeb it again" enters the create flow (request-type)', (
      tester,
    ) async {
      final repo = _FakeRepo({
        OrderHistoryTab.completed: [_o('c1', OrderRequestStatus.delivered)],
      });
      await tester.pumpWidget(_host(repo, pageSize: 20));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('order_history_completed_tab'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('order_history_reorder_cta_c1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('request-type-screen'), findsOneWidget);
    });

    testWidgets('the header survives 200% text without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(_host(repo, textScaleFactor: 2, pageSize: 20));
      await tester.pumpAndSettle();

      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders mirrored under Arabic without overflowing', (
      tester,
    ) async {
      // The card formats its date through `DateFormat.MMMd(locale)`, which
      // needs the non-default locale's symbols loaded.
      await initializeDateFormatting();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('ar1', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(
        _host(repo, locale: const Locale('ar'), pageSize: 20),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('order-history-card-ar1')), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('order-history-card-ar1'))),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('E4 illustration + the catalog tab seam', () {
    testWidgets('the empty state draws E4\'s parcel, not E1', (tester) async {
      final repo = _FakeRepo(const {});
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      final empty = tester.widget<JeebEmptyState>(
        find.byKey(const Key('order-history-empty-active')),
      );
      expect(empty.variant, JeebEmptyStateVariant.parcel);
      expect(empty.variant, isNot(JeebEmptyStateVariant.e1));
    });

    testWidgets('the error twin draws the same parcel', (tester) async {
      final repo = _ThrowingRepo();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<JeebEmptyState>(
              find.descendant(
                of: find.byKey(const Key('order-history-error')),
                matching: find.byType(JeebEmptyState),
              ),
            )
            .variant,
        JeebEmptyStateVariant.parcel,
      );
    });

    for (final tab in <OrderHistoryTab>[
      OrderHistoryTab.completed,
      OrderHistoryTab.cancelled,
    ]) {
      testWidgets('initialTab ${tab.name} loads THAT tab, not Active', (
        tester,
      ) async {
        final repo = _FakeRepo({
          OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
          OrderHistoryTab.completed: [_o('c1', OrderRequestStatus.delivered)],
          OrderHistoryTab.cancelled: [_o('x1', OrderRequestStatus.cancelled)],
        });
        await tester.pumpWidget(
          _host(repo, pageSize: 20, initialTab: tab),
        );
        await tester.pumpAndSettle();

        expect(repo.calls.single.tab, tab);
        expect(
          find.byKey(Key('order-history-list-${tab.name}')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('order-history-card-a1')), findsNothing);
      });
    }

    testWidgets('the default still lands on Active', (tester) async {
      final repo = _FakeRepo({
        OrderHistoryTab.active: [_o('a1', OrderRequestStatus.enRoute)],
      });
      await tester.pumpWidget(_host(repo, pageSize: 20));
      await tester.pumpAndSettle();

      expect(repo.calls.single.tab, OrderHistoryTab.active);
      expect(find.byKey(const Key('order-history-card-a1')), findsOneWidget);
    });
  });

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
  // Scoped to the dialog: the screen behind it stays mounted under the
  // non-opaque dialog route, and the redesigned tab pill now renders a bare
  // count digit that would otherwise collide with a day-of-month cell.
  final dayCell = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.text('$day'),
  );
  expect(dayCell, findsOneWidget);
  await tester.tap(dayCell);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
