// Designed states for `OrderHistoryScreen` (the Delivery tab) — ONE source of

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/order_history/application/order_history_cubit.dart';
import '../../../features/order_history/application/order_history_state.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';

// ─────────────────────────────────────────────────────────────────────────

/// Answers every read from [orders], bucketed by [OrderRequestStatus.tab].
/// The bucketing is what the gateway's `status` filter does, and it is why the
/// Completed and Cancelled tabs of a populated state show their own (empty)
class OrderHistoryScreenStaticOrders implements OrderRepository {
  const OrderHistoryScreenStaticOrders(this.orders);

  final List<OrderSummary> orders;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    return OrderPage(
      items: orders
          .where((OrderSummary order) => order.status.tab == tab)
          .toList(growable: false),
      page: page,
      hasMore: false,
    );
  }
}

/// Every read throws — the COLD-load failure.
/// It MUST throw [OrderRepositoryException] and nothing else: that is the only
/// type [OrderHistoryCubit] catches, so any other error escapes the cubit and
class OrderHistoryScreenFailingOrders implements OrderRepository {
  const OrderHistoryScreenFailingOrders(this.kind);

  final OrderRepositoryErrorKind kind;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async =>
      throw OrderRepositoryException(kind);
}

/// Never completes — the first page is still in flight.
/// Not a hypothetical: `OrderHistoryScreen.initState` posts `initialLoad()` for
/// the frame after mount, so every customer who opens the Delivery tab sees
class OrderHistoryScreenStalledOrders implements OrderRepository {
  const OrderHistoryScreenStalledOrders();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) =>
      Completer<OrderPage>().future;
}

/// Page 1 lands, page 2 never does — the NEXT-page wait, which the cold-load
/// fixtures cannot reach because they answer every page identically.
class OrderHistoryScreenPaginatingOrders implements OrderRepository {
  const OrderHistoryScreenPaginatingOrders(this.orders);

  final List<OrderSummary> orders;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    if (page > 1) return Completer<OrderPage>().future;
    return OrderPage(
      items: orders
          .where((OrderSummary order) => order.status.tab == tab)
          .toList(growable: false),
      page: page,
      hasMore: true,
    );
  }
}

/// Rows only when NO date range is applied — the ES-06 filtered empty.
class OrderHistoryScreenFilteredEmptyOrders implements OrderRepository {
  const OrderHistoryScreenFilteredEmptyOrders(this.orders);

  final List<OrderSummary> orders;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final bool filtered = range.from != null || range.to != null;
    return OrderPage(
      items: filtered
          ? const <OrderSummary>[]
          : orders
              .where((OrderSummary order) => order.status.tab == tab)
              .toList(growable: false),
      page: page,
      hasMore: false,
    );
  }
}

/// A numeric `id` on the wire — ORDH-03's TypeError, classified as a parse
/// failure instead of stranding the tab in `loadingFirstPage`.
class OrderHistoryScreenParseFailingOrders implements OrderRepository {
  const OrderHistoryScreenParseFailingOrders();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async =>
      throw OrderRepositoryException(
        OrderRepositoryErrorKind.parse,
        TypeError(),
        const UnknownFailure(parse: true),
      );
}

/// Page 1 lands, page 2 THROWS — the EP-15 footer retry.
class OrderHistoryScreenLoadMoreFailingOrders implements OrderRepository {
  const OrderHistoryScreenLoadMoreFailingOrders(this.orders);

  final List<OrderSummary> orders;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    if (page > 1) {
      throw const OrderRepositoryException(
        OrderRepositoryErrorKind.network,
        null,
        NetworkFailure(offline: true),
      );
    }
    return OrderPage(
      items: orders
          .where((OrderSummary order) => order.status.tab == tab)
          .toList(growable: false),
      page: page,
      hasMore: true,
    );
  }
}

/// Drives [OrderHistoryCubit] to `loadingNextPage` the moment the first page
/// settles: the catalog never scrolls, so the screen's own trigger never fires.
Future<void> driveOrderHistoryToNextPage(OrderHistoryCubit cubit) async {
  await cubit.stream.firstWhere(
    (OrderHistoryState state) =>
        state.currentTab.status == OrderTabStatus.ready,
  );
  await cubit.loadMore();
}

// ─────────────────────────────────────────────────────────────────────────

/// The designed order lists, one per state.
/// Every cast prices its rows differently from every other cast, so a state
/// accidentally rewired to a neighbouring fixture shows a wrong number on
class OrderHistoryScreenOrders {
  const OrderHistoryScreenOrders._();

  /// The reference reading, verbatim from the Screen Catalog entry: two live
  /// requests at different points of the journey.
  static final List<OrderSummary> activePopulated = <OrderSummary>[
    OrderSummary(
      id: 'REQ-1042',
      createdAt: DateTime.utc(2026, 6, 20, 14, 30),
      pickupAddress: 'Hamra, Beirut',
      dropoffAddress: 'Achrafieh, Beirut',
      status: OrderRequestStatus.enRoute,
      tier: OrderTier.express,
      amountMinor: 1250,
      currency: 'USD',
    ),
    OrderSummary(
      id: 'REQ-1038',
      createdAt: DateTime.utc(2026, 6, 19, 9, 5),
      pickupAddress: 'Verdun, Beirut',
      dropoffAddress: 'Downtown, Beirut',
      status: OrderRequestStatus.matched,
      tier: OrderTier.flash,
      // No usable amount surfaced yet — renders the em-dash, never $0.00.
      amountMinor: null,
      currency: 'USD',
    ),
  ];

  /// R21's completed rows: the green check, the muted meta run and the glass
  /// `Jeeb it again` pill. Two, because one row cannot show the list rhythm.
  static final List<OrderSummary> completedPopulated = <OrderSummary>[
    OrderSummary(
      id: 'REQ-1039',
      createdAt: DateTime.utc(2026, 6, 26, 10, 20),
      pickupAddress: 'Spinneys Achrafieh',
      dropoffAddress: 'Achrafieh, Beirut',
      status: OrderRequestStatus.delivered,
      tier: OrderTier.express,
      amountMinor: 600,
      currency: 'USD',
    ),
    OrderSummary(
      id: 'REQ-1035',
      createdAt: DateTime.utc(2026, 6, 24, 10, 5),
      pickupAddress: 'Hamra notary',
      dropoffAddress: 'Verdun, Beirut',
      status: OrderRequestStatus.delivered,
      tier: OrderTier.standard,
      amountMinor: 1000,
      currency: 'USD',
    ),
  ];

  /// R21's expired rows — the faded treatment that keeps its orange
  /// `Re-broadcast` spark. Both terminal statuses, since they render alike.
  static final List<OrderSummary> cancelledPopulated = <OrderSummary>[
    OrderSummary(
      id: 'REQ-1030',
      createdAt: DateTime.utc(2026, 6, 20, 10, 45),
      pickupAddress: 'Ashrafieh florist',
      dropoffAddress: 'Mar Mikhael, Beirut',
      status: OrderRequestStatus.cancelled,
      // "no offers" — the row never priced, so it draws the em-dash.
      amountMinor: null,
      tier: OrderTier.flash,
      currency: 'USD',
    ),
    OrderSummary(
      id: 'REQ-1024',
      createdAt: DateTime.utc(2026, 6, 17, 16, 30),
      pickupAddress: 'Bourj Hammoud hardware',
      dropoffAddress: 'Dekwaneh, Beirut',
      status: OrderRequestStatus.disputed,
      tier: OrderTier.eco,
      amountMinor: 450,
      currency: 'USD',
    ),
  ];

  /// A read that SUCCEEDED and came back with zero rows.
  /// Worth its own name: "No orders yet" is also the exact surface a
  static const List<OrderSummary> none = <OrderSummary>[];

  /// What a narrowed date range leaves behind.
  /// The gateway applies `from`/`to` itself, so this is the RESULT of a filter
  static final List<OrderSummary> dateFilteredSlice = <OrderSummary>[
    OrderSummary(
      id: 'REQ-1051',
      createdAt: DateTime.utc(2026, 6, 18, 11, 15),
      pickupAddress: 'Ras Beirut',
      dropoffAddress: 'Ain El Mreisseh',
      status: OrderRequestStatus.pickedUp,
      tier: OrderTier.standard,
      amountMinor: 730,
      currency: 'USD',
    ),
  ];

  /// The layout ceiling: the longest plausible Beirut addresses beside the
  /// widest money token the app can produce.
  static final List<OrderSummary> longestContent = <OrderSummary>[
    OrderSummary(
      id: 'REQ-2200',
      createdAt: DateTime.utc(2026, 6, 21, 18, 45),
      pickupAddress: 'Pharmacie Al-Muhandis, Rue Abdel Aziz, Bloc B, third '
          'floor, beside the American University of Beirut main gate, Hamra, '
          'Beirut, Lebanon',
      dropoffAddress: 'Immeuble Trabulsi, Rue Sursock, the blue door beside '
          'the bakery, near the Greek Orthodox church, Achrafieh, Beirut, '
          'Lebanon',
      status: OrderRequestStatus.pickedUp,
      tier: OrderTier.onTheWay,
      amountMinor: 133500000,
      currency: 'LBP',
    ),
    OrderSummary(
      id: 'REQ-2201',
      createdAt: DateTime.utc(2026, 6, 21, 8, 0),
      pickupAddress: 'Dekwaneh',
      dropoffAddress: 'Bourj Hammoud',
      status: OrderRequestStatus.unknown,
      tier: OrderTier.eco,
      amountMinor: null,
      currency: 'USD',
    ),
  ];
}

/// The A5 fixtures, named for the catalog entries Stage 2 appends.
abstract final class OrderHistoryScreenFixtures {
  /// A date range hides every row — "No orders match this range", with a clear.
  static OrderRepository filteredEmptyRepository(List<OrderSummary> orders) =>
      OrderHistoryScreenFilteredEmptyOrders(orders);

  /// Empty under the JEEBER role — ES-07's role-aware copy.
  static OrderRepository jeeberEmptyRepository() =>
      const OrderHistoryScreenStaticOrders(<OrderSummary>[]);

  /// A malformed row — ORDH-03's parse classification.
  static OrderRepository parseFailingRepository() =>
      const OrderHistoryScreenParseFailingOrders();

  /// Page 2 throws — EP-15's footer retry, never a toast.
  static OrderRepository loadMoreFailingRepository(List<OrderSummary> orders) =>
      OrderHistoryScreenLoadMoreFailingOrders(orders);
}

/// The designed date range for the filtered state: a single calendar day.
/// Built through [OrderDateRange.forInclusiveDays] — the same constructor the
final OrderDateRange orderHistoryScreenFilterRange =
    OrderDateRange.forInclusiveDays(
  from: DateTime(2026, 6, 18),
  to: DateTime(2026, 6, 18),
);
