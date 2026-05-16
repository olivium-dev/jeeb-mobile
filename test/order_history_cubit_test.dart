import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/order_history/application/order_history_cubit.dart';
import 'package:jeeb_mobile/features/order_history/application/order_history_state.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

class _MockRepo extends Mock implements OrderRepository {}

class _FakeDateRange extends Fake implements OrderDateRange {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeDateRange());
    registerFallbackValue(OrderHistoryTab.active);
  });

  late _MockRepo repo;

  OrderSummary order(String id, {int amount = 100_00}) => OrderSummary(
        id: id,
        createdAt: DateTime.utc(2026, 5, 17),
        pickupAddress: 'A',
        dropoffAddress: 'B',
        status: OrderRequestStatus.delivered,
        tier: OrderTier.standard,
        amountMinor: amount,
        currency: 'USD',
      );

  OrderPage page(List<OrderSummary> items, {required int p, bool more = true}) =>
      OrderPage(items: items, page: p, hasMore: more);

  setUp(() {
    repo = _MockRepo();
  });

  OrderHistoryCubit build({int pageSize = 2}) =>
      OrderHistoryCubit(repository: repo, pageSize: pageSize);

  group('initialLoad', () {
    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'loads page 1 for the active tab and transitions to ready',
      build: build,
      setUp: () {
        when(() => repo.fetchPage(
              tab: OrderHistoryTab.active,
              page: 1,
              pageSize: 2,
              range: any(named: 'range'),
            )).thenAnswer((_) async => page([order('1'), order('2')], p: 1));
      },
      act: (c) => c.initialLoad(),
      expect: () => [
        predicate<OrderHistoryState>(
          (s) => s.currentTab.status == OrderTabStatus.loadingFirstPage,
        ),
        predicate<OrderHistoryState>(
          (s) =>
              s.currentTab.status == OrderTabStatus.ready &&
              s.currentTab.orders.length == 2 &&
              s.currentTab.hasMore,
        ),
      ],
    );

    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'flips to error state when the repo throws on a first-page load',
      build: build,
      setUp: () {
        when(() => repo.fetchPage(
              tab: any(named: 'tab'),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              range: any(named: 'range'),
            )).thenThrow(
          const OrderRepositoryException(OrderRepositoryErrorKind.network),
        );
      },
      act: (c) => c.initialLoad(),
      skip: 1, // skip the loadingFirstPage frame
      expect: () => [
        predicate<OrderHistoryState>(
          (s) =>
              s.currentTab.status == OrderTabStatus.error &&
              s.currentTab.errorKind == OrderTabErrorKind.network,
        ),
      ],
    );
  });

  group('loadMore', () {
    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'appends page 2 onto the existing list and bumps the page counter',
      build: build,
      seed: () => OrderHistoryState(
        tabs: {
          OrderHistoryTab.active: OrderTabState(
            orders: [order('1'), order('2')],
            page: 1,
            hasMore: true,
            status: OrderTabStatus.ready,
          ),
          OrderHistoryTab.completed: const OrderTabState(),
          OrderHistoryTab.cancelled: const OrderTabState(),
        },
      ),
      setUp: () {
        when(() => repo.fetchPage(
              tab: OrderHistoryTab.active,
              page: 2,
              pageSize: 2,
              range: any(named: 'range'),
            )).thenAnswer(
          (_) async => page([order('3'), order('4')], p: 2, more: false),
        );
      },
      act: (c) => c.loadMore(),
      expect: () => [
        predicate<OrderHistoryState>(
          (s) => s.currentTab.status == OrderTabStatus.loadingNextPage,
        ),
        predicate<OrderHistoryState>(
          (s) =>
              s.currentTab.status == OrderTabStatus.ready &&
              s.currentTab.orders.length == 4 &&
              s.currentTab.orders.last.id == '4' &&
              s.currentTab.page == 2 &&
              !s.currentTab.hasMore,
        ),
      ],
    );

    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'is a no-op when hasMore is false',
      build: build,
      seed: () => OrderHistoryState(
        tabs: {
          OrderHistoryTab.active: OrderTabState(
            orders: [order('1')],
            page: 1,
            hasMore: false,
            status: OrderTabStatus.ready,
          ),
          OrderHistoryTab.completed: const OrderTabState(),
          OrderHistoryTab.cancelled: const OrderTabState(),
        },
      ),
      act: (c) => c.loadMore(),
      expect: () => <OrderHistoryState>[],
      verify: (_) => verifyNever(() => repo.fetchPage(
            tab: any(named: 'tab'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
            range: any(named: 'range'),
          )),
    );

    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'keeps the list visible and surfaces a transient error when page 2 fails',
      build: build,
      seed: () => OrderHistoryState(
        tabs: {
          OrderHistoryTab.active: OrderTabState(
            orders: [order('1'), order('2')],
            page: 1,
            hasMore: true,
            status: OrderTabStatus.ready,
          ),
          OrderHistoryTab.completed: const OrderTabState(),
          OrderHistoryTab.cancelled: const OrderTabState(),
        },
      ),
      setUp: () {
        when(() => repo.fetchPage(
              tab: any(named: 'tab'),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
              range: any(named: 'range'),
            )).thenThrow(
          const OrderRepositoryException(OrderRepositoryErrorKind.server),
        );
      },
      act: (c) => c.loadMore(),
      skip: 1, // loadingNextPage frame
      expect: () => [
        predicate<OrderHistoryState>(
          (s) =>
              s.currentTab.status == OrderTabStatus.ready &&
              s.currentTab.errorKind == OrderTabErrorKind.server &&
              s.currentTab.orders.length == 2,
        ),
      ],
    );
  });

  group('selectTab', () {
    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'switches to the new tab and lazy-loads its first page',
      build: build,
      setUp: () {
        when(() => repo.fetchPage(
              tab: OrderHistoryTab.completed,
              page: 1,
              pageSize: 2,
              range: any(named: 'range'),
            )).thenAnswer((_) async => page([order('c1')], p: 1, more: false));
      },
      act: (c) => c.selectTab(OrderHistoryTab.completed),
      expect: () => [
        predicate<OrderHistoryState>(
          (s) => s.activeTab == OrderHistoryTab.completed,
        ),
        predicate<OrderHistoryState>(
          (s) =>
              s.activeTab == OrderHistoryTab.completed &&
              s.currentTab.status == OrderTabStatus.loadingFirstPage,
        ),
        predicate<OrderHistoryState>(
          (s) =>
              s.activeTab == OrderHistoryTab.completed &&
              s.currentTab.status == OrderTabStatus.ready &&
              s.currentTab.orders.first.id == 'c1',
        ),
      ],
    );
  });

  group('applyDateRange', () {
    blocTest<OrderHistoryCubit, OrderHistoryState>(
      'wipes all tabs and reloads the current tab with the new filter',
      build: build,
      seed: () => OrderHistoryState(
        activeTab: OrderHistoryTab.completed,
        tabs: {
          OrderHistoryTab.active: OrderTabState(
            orders: [order('stale')],
            page: 1,
            status: OrderTabStatus.ready,
          ),
          OrderHistoryTab.completed: OrderTabState(
            orders: [order('stale-c')],
            page: 1,
            status: OrderTabStatus.ready,
          ),
          OrderHistoryTab.cancelled: const OrderTabState(),
        },
      ),
      setUp: () {
        when(() => repo.fetchPage(
              tab: OrderHistoryTab.completed,
              page: 1,
              pageSize: 2,
              range: any(named: 'range'),
            )).thenAnswer((_) async => page([order('fresh')], p: 1, more: false));
      },
      act: (c) => c.applyDateRange(
        OrderDateRange(
          from: DateTime.utc(2026, 5, 1),
          to: DateTime.utc(2026, 5, 17),
        ),
      ),
      expect: () => [
        predicate<OrderHistoryState>((s) =>
            s.dateRange.from != null &&
            s.tabs[OrderHistoryTab.active]!.orders.isEmpty &&
            s.tabs[OrderHistoryTab.completed]!.orders.isEmpty),
        predicate<OrderHistoryState>((s) =>
            s.currentTab.status == OrderTabStatus.loadingFirstPage),
        predicate<OrderHistoryState>((s) =>
            s.currentTab.status == OrderTabStatus.ready &&
            s.currentTab.orders.first.id == 'fresh'),
      ],
    );
  });
}
