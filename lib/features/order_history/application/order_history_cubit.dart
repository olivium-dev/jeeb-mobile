import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/order_repository.dart';
import '../domain/order_summary.dart';
import 'order_history_state.dart';

/// Owns the three-tabbed order history list.
///
/// Pagination model: each tab keeps its own page counter + accumulated
/// items. The date-range filter is global (it applies to whichever tab the
/// user is currently looking at and resets all three tabs on change),
/// matching the brief: "Filter by date range" is screen-level, not per-tab.
class OrderHistoryCubit extends Cubit<OrderHistoryState> {
  OrderHistoryCubit({
    required OrderRepository repository,
    this.pageSize = 20,
  })  : _repository = repository,
        super(const OrderHistoryState());

  final OrderRepository _repository;
  final int pageSize;

  /// Switches tab. Triggers a first-page load if this tab has never been
  /// loaded; otherwise reuses the cached list (so a tap-tap-tap doesn't
  /// burn requests).
  Future<void> selectTab(OrderHistoryTab tab) async {
    if (tab == state.activeTab) return;
    emit(state.copyWith(activeTab: tab));
    if (state.tabs[tab]!.status == OrderTabStatus.initial) {
      await _loadFirstPage(tab);
    }
  }

  /// Called by the screen's `initState`. Idempotent — re-entry is a no-op
  /// if the active tab already has data or a load is in flight.
  Future<void> initialLoad() async {
    final current = state.currentTab;
    if (current.status != OrderTabStatus.initial) return;
    await _loadFirstPage(state.activeTab);
  }

  /// Pull-to-refresh handler. Resets the current tab's page counter and
  /// reloads page 1. Leaves the other tabs alone.
  Future<void> refresh() => _loadFirstPage(state.activeTab, isRefresh: true);

  /// Infinite-scroll trigger. No-op when we're already loading or when the
  /// server has signalled there's nothing more.
  Future<void> loadMore() async {
    final tab = state.activeTab;
    final tabState = state.tabs[tab]!;
    if (!tabState.hasMore) return;
    if (tabState.status == OrderTabStatus.loadingNextPage ||
        tabState.status == OrderTabStatus.loadingFirstPage ||
        tabState.status == OrderTabStatus.refreshing) {
      return;
    }
    if (tabState.status != OrderTabStatus.ready) return;

    emit(state.withTabState(
      tab,
      tabState.copyWith(
        status: OrderTabStatus.loadingNextPage,
        clearError: true,
      ),
    ));
    try {
      final next = await _repository.fetchPage(
        tab: tab,
        page: tabState.page + 1,
        pageSize: pageSize,
        range: state.dateRange,
      );
      emit(state.withTabState(
        tab,
        tabState.copyWith(
          orders: [...tabState.orders, ...next.items],
          page: next.page,
          hasMore: next.hasMore,
          status: OrderTabStatus.ready,
        ),
      ));
    } on OrderRepositoryException catch (e) {
      // Failing a next-page load keeps the already-loaded items visible;
      // we go back to `ready` and the screen surfaces a transient snackbar
      // via the listener rather than blowing up the whole list.
      emit(state.withTabState(
        tab,
        tabState.copyWith(
          status: OrderTabStatus.ready,
          errorKind: _mapError(e.kind),
        ),
      ));
    }
  }

  /// Applies a new date-range filter. Wipes all three tabs because the
  /// gateway applies the date filter per-tab and we don't want a stale
  /// mix of pre- and post-filter rows.
  Future<void> applyDateRange(OrderDateRange range) async {
    if (range == state.dateRange) return;
    final reset = {
      for (final t in OrderHistoryTab.values) t: const OrderTabState(),
    };
    emit(state.copyWith(tabs: reset, dateRange: range));
    await _loadFirstPage(state.activeTab);
  }

  /// Convenience for the filter sheet's "Clear" button.
  Future<void> clearDateRange() => applyDateRange(const OrderDateRange());

  Future<void> _loadFirstPage(
    OrderHistoryTab tab, {
    bool isRefresh = false,
  }) async {
    final current = state.tabs[tab]!;
    emit(state.withTabState(
      tab,
      current.copyWith(
        status: isRefresh
            ? OrderTabStatus.refreshing
            : OrderTabStatus.loadingFirstPage,
        clearError: true,
      ),
    ));
    try {
      final page = await _repository.fetchPage(
        tab: tab,
        page: 1,
        pageSize: pageSize,
        range: state.dateRange,
      );
      emit(state.withTabState(
        tab,
        OrderTabState(
          orders: page.items,
          page: page.page,
          hasMore: page.hasMore,
          status: OrderTabStatus.ready,
        ),
      ));
    } on OrderRepositoryException catch (e) {
      // On a refresh, the previous list stays visible and we just surface
      // an error indicator — first-time loads flip to the full error state.
      emit(state.withTabState(
        tab,
        isRefresh
            ? current.copyWith(
                status: OrderTabStatus.ready,
                errorKind: _mapError(e.kind),
              )
            : current.copyWith(
                status: OrderTabStatus.error,
                errorKind: _mapError(e.kind),
              ),
      ));
    }
  }

  static OrderTabErrorKind _mapError(OrderRepositoryErrorKind kind) {
    switch (kind) {
      case OrderRepositoryErrorKind.network:
        return OrderTabErrorKind.network;
      case OrderRepositoryErrorKind.server:
      case OrderRepositoryErrorKind.parse:
        return OrderTabErrorKind.server;
    }
  }
}
