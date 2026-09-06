// EP-15 / ORDH-04: a dead NEXT page is a footer the reader can act on — never
// a bare toast, and never the screen's error rung. The footer's in-flight line
// is the pagination headline, not the COLD-load one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_state.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_screen.dart';

import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

OrderSummary _row(String id) => OrderSummary(
  id: id,
  createdAt: DateTime.utc(2026, 6, 18, 9),
  pickupAddress: 'Hamra',
  dropoffAddress: 'Achrafieh',
  status: OrderRequestStatus.pickedUp,
  tier: OrderTier.express,
  amountMinor: 1500,
  currency: 'USD',
);

/// Page 1 lands, page 2 throws — the only way to reach the footer.
class _LoadMoreFails implements OrderRepository {
  _LoadMoreFails();

  final List<int> pages = <int>[];

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    pages.add(page);
    if (page > 1) throw const NetworkFailure(offline: true);
    return OrderPage(
      items: tab == OrderHistoryTab.active
          ? <OrderSummary>[_row('REQ-1')]
          : const <OrderSummary>[],
      page: page,
      hasMore: true,
    );
  }
}

Widget _harness(OrderHistoryCubit cubit, Locale locale) => wrapMidnight(
  SizedBox(
    height: 900,
    child: BlocProvider<OrderHistoryCubit>.value(
      value: cubit,
      child: const OrderHistoryScreen(),
    ),
  ),
  locale: locale,
  scrollable: false,
);

void main() {
  test('a failed page sets loadMoreError and NOT errorKind', () async {
    final _LoadMoreFails repo = _LoadMoreFails();
    final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
    addTearDown(cubit.close);

    await cubit.initialLoad();
    await cubit.loadMore();

    expect(cubit.state.currentTab.status, OrderTabStatus.ready);
    expect(cubit.state.currentTab.loadMoreError, isA<NetworkFailure>());
    expect(
      cubit.state.currentTab.errorKind,
      isNull,
      reason: 'pagination must not reach the snack listener',
    );
  });

  for (final Locale locale in kFailureLocales) {
    testWidgets('${locale.languageCode}: the footer retry refetches page 2', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final _LoadMoreFails repo = _LoadMoreFails();
      final OrderHistoryCubit cubit = OrderHistoryCubit(repository: repo);
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pumpAndSettle();
      await cubit.loadMore();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('order_history_load_more_error'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      final int before = repo.pages.where((int p) => p == 2).length;
      await tester.tap(
        find.bySemanticsIdentifier('order_history_load_more_retry'),
      );
      await tester.pumpAndSettle();
      expect(repo.pages.where((int p) => p == 2).length, greaterThan(before));
    });
  }

  testWidgets('ORDH-04 · the footer wait uses the pagination headline', (
    WidgetTester tester,
  ) async {
    useReduceMotion(tester);
    final OrderHistoryCubit cubit = OrderHistoryCubit(repository: _Stalling());
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(cubit, const Locale('en')));
    await tester.pumpAndSettle();
    unawaitedLoadMore(cubit);
    await tester.pumpAndSettle();
    expect(cubit.state.currentTab.status, OrderTabStatus.loadingNextPage);

    // Gate 11: by identifier, never by visible text.
    expect(
      find.bySemanticsIdentifier('order_history_loading_more'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('order_history_loading'),
      findsNothing,
    );
  });
}

void unawaitedLoadMore(OrderHistoryCubit cubit) {
  cubit.loadMore();
}

/// Page 1 lands, page 2 never resolves — the in-flight footer. A Completer
/// that is never completed holds no timer, so the test leaves none pending.
class _Stalling implements OrderRepository {
  _Stalling();

  final Completer<OrderPage> _never = Completer<OrderPage>();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) {
    if (page > 1) return _never.future;
    return Future<OrderPage>.value(
      OrderPage(
        items: tab == OrderHistoryTab.active
            ? <OrderSummary>[_row('REQ-1')]
            : const <OrderSummary>[],
        page: page,
        hasMore: true,
      ),
    );
  }
}
