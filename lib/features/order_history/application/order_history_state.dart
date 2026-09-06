import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/order_summary.dart';

class OrderTabState extends Equatable {
  const OrderTabState({
    this.orders = const [],
    this.page = 0,
    this.hasMore = true,
    this.status = OrderTabStatus.initial,
    this.settled = false,
    this.errorKind,
    this.failure,
    this.loadMoreError,
    this.refreshError,
  });

  final List<OrderSummary> orders;

  final int page;

  final bool hasMore;

  final OrderTabStatus status;

  /// True once a fetch has RETURNED for this tab. A refresh over a tab that
  /// never settled is a first load and must paint the loading rung.
  final bool settled;

  /// Legacy 2-value display kind; [failure] is the classifier the screen reads.
  final OrderTabErrorKind? errorKind;

  /// The classified failure behind [errorKind].
  final AppFailure? failure;

  /// A failed NEXT-page fetch: a footer retry, never the screen's error rung.
  final AppFailure? loadMoreError;

  /// A failed SILENT refresh over rows that are already on screen: a warm band
  /// above the list, never the pagination footer.
  final AppFailure? refreshError;

  OrderTabState copyWith({
    List<OrderSummary>? orders,
    int? page,
    bool? hasMore,
    OrderTabStatus? status,
    bool? settled,
    OrderTabErrorKind? errorKind,
    AppFailure? failure,
    AppFailure? loadMoreError,
    AppFailure? refreshError,
    bool clearError = false,
    bool clearLoadMoreError = false,
    bool clearRefreshError = false,
  }) {
    return OrderTabState(
      orders: orders ?? this.orders,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      status: status ?? this.status,
      settled: settled ?? this.settled,
      errorKind: clearError ? errorKind : (errorKind ?? this.errorKind),
      failure: clearError ? failure : (failure ?? this.failure),
      loadMoreError: clearLoadMoreError
          ? loadMoreError
          : (loadMoreError ?? this.loadMoreError),
      refreshError: clearRefreshError
          ? refreshError
          : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => [
        orders,
        page,
        hasMore,
        status,
        settled,
        errorKind,
        failure,
        loadMoreError,
        refreshError,
      ];
}

enum OrderTabStatus {
  initial,

  loadingFirstPage,

  refreshing,

  loadingNextPage,

  ready,

  error,
}

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
