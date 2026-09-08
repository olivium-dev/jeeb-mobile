// X2 regression lock — device run: pull-to-refresh on the Cancelled tab was
// physically inert. A four-row list is shorter than the viewport, so the
// default physics refuse the drag and the RefreshIndicator never arms.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _CountingRepo implements OrderRepository {
  _CountingRepo(this._orders);

  final List<OrderSummary> _orders;
  int fetches = 0;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    fetches++;
    if (page > 1) {
      return OrderPage(items: const <OrderSummary>[], page: page, hasMore: false);
    }
    return OrderPage(
      items: _orders.where((OrderSummary o) => o.status.tab == tab).toList(),
      page: page,
      hasMore: false,
    );
  }
}

/// The four Cancelled rows the device actually held.
List<OrderSummary> _cancelledRows() => <OrderSummary>[
  for (final (String id, String title) in const <(String, String)>[
    ('defb1f07', 'F8-resolve-probe-parcel'),
    ('dc5d0f2e', 'validation test parcel'),
    ('f26b3601', 'Two boxes of panadol from the pharmacy'),
    ('8a87f41f', 'Deliver 2kg of parcels'),
  ])
    OrderSummary(
      id: id,
      displayId: id,
      title: title,
      createdAt: DateTime.utc(2026, 9, 5, 11, 21),
      pickupAddress: 'Current location',
      dropoffAddress: 'Current location',
      status: OrderRequestStatus.cancelled,
      tier: OrderTier.standard,
      amountMinor: null,
      currency: 'USD',
    ),
];

Widget _host(OrderRepository repo, {double textScale = 1.1}) {
  final OrderHistoryCubit cubit = OrderHistoryCubit(
    repository: repo,
    pageSize: 20,
  );
  return MaterialApp(
    theme: ThemeData.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: BlocProvider<OrderHistoryCubit>.value(
      value: cubit,
      child: const Scaffold(
        body: OrderHistoryScreen(initialTab: OrderHistoryTab.cancelled),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'a SHORT list still arms pull-to-refresh at the stock 1.1 font scale',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final _CountingRepo repo = _CountingRepo(_cancelledRows());
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('F8-resolve-probe-parcel'), findsOneWidget);
      final int afterFirstLoad = repo.fetches;

      await tester.fling(
        find.byKey(const Key('order-history-list-cancelled')),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        repo.fetches,
        greaterThan(afterFirstLoad),
        reason: 'the drag must reach the RefreshIndicator and refetch',
      );
    },
  );

  // F5 (tab half) — device C14.png clipped the selected `Cancelled 4` pill to
  // `Car`: the scrolling pill row never brought the selected tab into view.
  testWidgets('@2.0 the selected Cancelled pill is fully on screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(_CountingRepo(_cancelledRows()), textScale: 2),
    );
    await tester.pumpAndSettle();

    final Finder pill = find.bySemanticsIdentifier('order_history_cancelled_tab');
    expect(pill, findsOneWidget);
    final Rect rect = tester.getRect(pill);
    final double screenWidth = tester.view.physicalSize.width /
        tester.view.devicePixelRatio;

    expect(rect.left, greaterThanOrEqualTo(-0.5));
    expect(
      rect.right,
      lessThanOrEqualTo(screenWidth + 0.5),
      reason: 'the selected pill must not sit off the viewport edge',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the drag reaches the list physics (overscroll is accepted)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(_CountingRepo(_cancelledRows())));
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('order-history-list-cancelled')),
        matching: find.byType(Scrollable),
        matchRoot: true,
      ),
    );
    expect(
      scrollable.position.physics.shouldAcceptUserOffset(scrollable.position),
      isTrue,
      reason: 'a list shorter than the viewport must still accept the drag',
    );
  });
}
