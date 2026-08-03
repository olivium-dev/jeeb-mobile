import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/order_repository.dart';
import '../domain/order_summary.dart';
import 'order_history_state.dart';

class OrderHistoryCubit extends Cubit<OrderHistoryState> {
  OrderHistoryCubit({
    required OrderRepository repository,
    this.pageSize = 20,
  })  : _repository = repository,
        super(const OrderHistoryState());

  final OrderRepository _repository;
  final int pageSize;

  Future<void> selectTab(OrderHistoryTab tab) async {
    if (tab == state.activeTab) return;
    emit(state.copyWith(activeTab: tab));
    if (state.tabs[tab]!.status == OrderTabStatus.initial) {
      await _loadFirstPage(tab);
    }
  }

  Future<void> initialLoad() async {
    final current = state.currentTab;
    if (current.status != OrderTabStatus.initial) return;
    await _loadFirstPage(state.activeTab);
  }

  Future<void> refresh() => _loadFirstPage(state.activeTab, isRefresh: true);

  /// SILENT re-pull for an automatic trigger (shell-tab refocus, app resume,
  /// an `order` push). Distinct from [refresh] in exactly two ways, and both
  Future<void> refreshSilently() async {
    if (state.currentTab.status == OrderTabStatus.initial) return;
    await _loadFirstPage(state.activeTab, isRefresh: true);
  }

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
  Future<void> applyDateRange(OrderDateRange range) async {
    if (range == state.dateRange) return;
    final reset = {
      for (final t in OrderHistoryTab.values) t: const OrderTabState(),
    };
    emit(state.copyWith(tabs: reset, dateRange: range));
    await _loadFirstPage(state.activeTab);
  }

  Future<void> clearDateRange() => applyDateRange(const OrderDateRange());

  bool _firstPageInFlight = false;

  Future<void> _loadFirstPage(
    OrderHistoryTab tab, {
    bool isRefresh = false,
  }) async {
    if (_firstPageInFlight) return;
    _firstPageInFlight = true;
    try {
      await _loadFirstPageInner(tab, isRefresh: isRefresh);
    } finally {
      _firstPageInFlight = false;
    }
  }

  Future<void> _loadFirstPageInner(
    OrderHistoryTab tab, {
    required bool isRefresh,
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
