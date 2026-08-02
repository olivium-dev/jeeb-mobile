import 'package:equatable/equatable.dart';

import '../domain/order_summary.dart';

class OrderTabState extends Equatable {
  const OrderTabState({
    this.orders = const [],
    this.page = 0,
    this.hasMore = true,
    this.status = OrderTabStatus.initial,
    this.errorKind,
  });

  final List<OrderSummary> orders;

  final int page;

  final bool hasMore;

  final OrderTabStatus status;

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
