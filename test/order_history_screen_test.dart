import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._byTag);
  final Map<String, String> _byTag;
  @override
  bool isSupported(Locale locale) => _byTag.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _byTag[locale.languageCode]!);
  @override
  bool shouldReload(_SyncDelegate old) => false;
}

class _FakeRepo implements OrderRepository {
  _FakeRepo(this._pages);

  final Map<OrderHistoryTab, List<OrderPage>> _pages;
  final Map<OrderHistoryTab, int> _calls = {};

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final call = _calls.update(tab, (v) => v + 1, ifAbsent: () => 0);
    final list = _pages[tab] ?? const [];
    if (call >= list.length) {
      return OrderPage(items: const [], page: page, hasMore: false);
    }
    return list[call];
  }
}

late _SyncDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncDelegate({'en': en, 'ar': ar});
}

OrderSummary _o(String id, OrderRequestStatus status) => OrderSummary(
      id: id,
      createdAt: DateTime.utc(2026, 5, 17, 10),
      pickupAddress: 'Pickup $id',
      dropoffAddress: 'Dropoff $id',
      status: status,
      tier: OrderTier.express,
      amountMinor: 1234_00,
      currency: 'USD',
    );

Widget _host(OrderRepository repo) {
  final cubit = OrderHistoryCubit(repository: repo, pageSize: 2);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: OrderHistoryScreen()),
        ),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => Scaffold(
          body: Text('detail-${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  setUpAll(_loadArb);

  testWidgets('renders the three tabs', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [
        OrderPage(items: [_o('a1', OrderRequestStatus.enRoute)], page: 1, hasMore: false),
      ],
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
        OrderPage(
          items: [
            _o('a1', OrderRequestStatus.enRoute),
            _o('a2', OrderRequestStatus.pickedUp),
          ],
          page: 1,
          hasMore: false,
        ),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('order-history-card-a1')), findsOneWidget);
    expect(find.byKey(const Key('order-history-card-a2')), findsOneWidget);
  });

  testWidgets('shows the per-tab empty state when the active list is empty',
      (tester) async {
    final repo = _FakeRepo(const {});
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('order-history-empty-active')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a card navigates to /orders/:id', (tester) async {
    final repo = _FakeRepo({
      OrderHistoryTab.active: [
        OrderPage(
          items: [_o('xyz', OrderRequestStatus.enRoute)],
          page: 1,
          hasMore: false,
        ),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-history-card-xyz')));
    await tester.pumpAndSettle();

    expect(find.text('detail-xyz'), findsOneWidget);
  });
}
