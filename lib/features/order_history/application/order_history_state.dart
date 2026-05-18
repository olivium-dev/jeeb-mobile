import 'package:equatable/equatable.dart';

import '../domain/order_summary.dart';

/// Per-tab pagination + loading state. The full screen state is just
/// `{tab → OrderTabState}` plus the active tab + date filter, so the
/// active/completed/cancelled lists are isolated from each other (a refresh
/// on Active doesn't blow away the user's scroll position on Completed).
class OrderTabState extends Equatable {
  const OrderTabState({
    this.orders = const [],
    this.page = 0,
    this.hasMore = true,
    this.status = OrderTabStatus.initial,
    this.errorKind,
  });

  final List<OrderSummary> orders;

  /// Highest page number we've successfully loaded. 0 means "nothing yet".
  final int page;

  /// `false` once the server returned a short page — stops infinite scroll.
  final bool hasMore;

  final OrderTabStatus status;

  /// Populated only when [status] is [OrderTabStatus.error]; cleared on the
  /// next attempt so the UI never shows a stale error after a retry succeeds.
  final OrderTabErrorKind? errorKind;

  OrderTabState copyWith({
    List<OrderSummary>? orders,
    int? page,
    bool? hasMore,
    OrderTabStatus? status,
    OrderTabErrorKind? errorKind,
    bool clearError = false,
  }) {
    return OrderTabState(
      orders: orders ?? this.orders,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      status: status ?? this.status,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
    );
  }

  @override
  List<Object?> get props => [orders, page, hasMore, status, errorKind];
}

enum OrderTabStatus {
  /// Never fetched; UI shows the empty-skeleton.
  initial,

  /// First page in flight; UI shows a centered spinner.
  loadingFirstPage,

  /// Pull-to-refresh in flight; UI keeps the list visible and the spinner
  /// is owned by `OmdsPullToRefresh` (Material `RefreshIndicator` under the hood).
  refreshing,

  /// Next-page in flight; UI shows a footer spinner under the list.
  loadingNextPage,

  /// At least one page loaded successfully.
  ready,

  /// First-page load failed; UI shows the error state with a retry CTA.
  error,
}

/// Coarse-grained failure reason — the exact Dio error is logged but not
/// shown to the user.
enum OrderTabErrorKind { network, server }

class OrderHistoryState extends Equatable {
  const OrderHistoryState({
    this.activeTab = OrderHistoryTab.active,
    this.tabs = const {
      OrderHistoryTab.active: OrderTabState(),
      OrderHistoryTab.completed: OrderTabState(),
      OrderHistoryTab.cancelled: OrderTabState(),
    },
    this.dateRange = const OrderDateRange(),
  });

  final OrderHistoryTab activeTab;
  final Map<OrderHistoryTab, OrderTabState> tabs;
  final OrderDateRange dateRange;

  OrderTabState get currentTab => tabs[activeTab]!;

  OrderHistoryState copyWith({
    OrderHistoryTab? activeTab,
    Map<OrderHistoryTab, OrderTabState>? tabs,
    OrderDateRange? dateRange,
  }) {
    return OrderHistoryState(
      activeTab: activeTab ?? this.activeTab,
      tabs: tabs ?? this.tabs,
      dateRange: dateRange ?? this.dateRange,
    );
  }

  OrderHistoryState withTabState(
    OrderHistoryTab tab,
    OrderTabState newState,
  ) {
    final next = Map<OrderHistoryTab, OrderTabState>.from(tabs);
    next[tab] = newState;
    return copyWith(tabs: next);
  }

  @override
  List<Object?> get props => [activeTab, tabs, dateRange];
}
