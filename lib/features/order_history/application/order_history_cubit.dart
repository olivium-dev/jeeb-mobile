import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
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
  /// an `order` push). Its failures never raise a snack.
  Future<void> refreshSilently() async {
    if (state.currentTab.status == OrderTabStatus.initial) return;
    await _loadFirstPage(state.activeTab, isRefresh: true, silent: true);
  }

  /// One-shot clear after the warm refresh snack has been shown.
  void acknowledgeTabError([OrderHistoryTab? tab]) {
    final OrderHistoryTab target = tab ?? state.activeTab;
    final OrderTabState current = state.tabs[target]!;
    if (current.failure == null && current.errorKind == null) return;
    emit(state.withTabState(target, current.copyWith(clearError: true)));
  }

  /// Clears the warm refresh band after the user dismisses it.
  void acknowledgeRefreshError([OrderHistoryTab? tab]) {
    final OrderHistoryTab target = tab ?? state.activeTab;
    final OrderTabState current = state.tabs[target]!;
    if (current.refreshError == null) return;
    emit(state.withTabState(target, current.copyWith(clearRefreshError: true)));
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
        clearLoadMoreError: true,
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
          clearLoadMoreError: true,
        ),
      ));
    } catch (e) {
      // EP-15: a dead NEXT page is a footer retry, never the screen's error
      // rung and never a toast.
      emit(state.withTabState(
        tab,
        tabState.copyWith(
          status: OrderTabStatus.ready,
          loadMoreError: _classify(e),
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

  /// Per-tab, so `selectTab`'s load is never dropped while another tab loads.
  final Set<OrderHistoryTab> _firstPageInFlight = <OrderHistoryTab>{};

  Future<void> _loadFirstPage(
    OrderHistoryTab tab, {
    bool isRefresh = false,
    bool silent = false,
  }) async {
    if (!_firstPageInFlight.add(tab)) return;
    try {
      await _loadFirstPageInner(tab, isRefresh: isRefresh, silent: silent);
    } finally {
      _firstPageInFlight.remove(tab);
    }
  }

  Future<void> _loadFirstPageInner(
    OrderHistoryTab tab, {
    required bool isRefresh,
    bool silent = false,
  }) async {
    final current = state.tabs[tab]!;
    // F1: a "refresh" with nothing to keep (error rung, never settled, no rows)
    // is a FIRST load — painting `refreshing` there shows the empty rung.
    final bool warm = isRefresh &&
        current.status != OrderTabStatus.error &&
        (current.settled || current.orders.isNotEmpty);
    emit(state.withTabState(
      tab,
      current.copyWith(
        status:
            warm ? OrderTabStatus.refreshing : OrderTabStatus.loadingFirstPage,
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
          settled: true,
        ),
      ));
    } catch (e) {
      emit(state.withTabState(tab, _failedTabState(
        current,
        e,
        isRefresh: isRefresh,
        silent: silent,
      )));
    }
  }

  /// ORDH-01: a refresh that fails over an EMPTY list is an error rung, not a
  /// "No orders yet". A silent re-pull never raises the snack listener.
  OrderTabState _failedTabState(
    OrderTabState current,
    Object error, {
    required bool isRefresh,
    required bool silent,
  }) {
    final AppFailure failure = _classify(error);
    final OrderTabErrorKind kind = error is OrderRepositoryException
        ? _mapError(error.kind)
        : _kindOf(failure);
    if (isRefresh && current.orders.isNotEmpty) {
      return silent
          ? current.copyWith(
              status: OrderTabStatus.ready,
              refreshError: failure,
            )
          : current.copyWith(
              status: OrderTabStatus.ready,
              errorKind: kind,
              failure: failure,
            );
    }
    return current.copyWith(
      status: OrderTabStatus.error,
      errorKind: kind,
      failure: failure,
    );
  }

  static AppFailure _classify(Object error) => error is OrderRepositoryException
      ? (error.failure ?? AppFailure.of(error.cause ?? error))
      : AppFailure.of(error);

  static OrderTabErrorKind _kindOf(AppFailure failure) =>
      failure is NetworkFailure || failure is TimeoutFailure
          ? OrderTabErrorKind.network
          : OrderTabErrorKind.server;

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
