// Designed states for `OrderHistoryScreen` (the Delivery tab) — ONE source of
// truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_08_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/order_history/presentation/
//     order_history_screen.dart                         the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's four states were hand-built inside the entry file: a private
// `_FakeOrderRepository` with a nullable `page` + `errorKind`, a
// `_PendingOrderRepository` that never resolves, and one inline `OrderPage`.
// They moved here whole when the screen got a preview section, because two
// copies of the same "designed state" drift and the catalog is the one a
// designer signs off against.
//
// Two things changed in the move, neither of them to what the catalog RENDERS:
//
//  * one repository with two nullable flags became three, each named after the
//    branch it drives, so a state can no longer read as "static, probably fine"
//    when it is really the error path;
//  * [OrderHistoryScreenStaticOrders] buckets its rows by
//    `OrderRequestStatus.tab` the way the gateway's `status` filter does, so
//    tapping Completed or Cancelled in either dev surface shows THAT tab's
//    content instead of the Active list repeated three times. The catalog's
//    Active states are unaffected — every row in [activePopulated] is an
//    Active-tab status — and the same fake already ships in the `OrdersTab`
//    preview section.
//
// [activePopulated] is verbatim: the same two ids, timestamps, addresses,
// tiers, amounts and currency the entry file carried.
//
// Two casts are NEW and belong only to the preview canvas, which reviews states
// the catalog does not carry:
//
//   [dateFilteredSlice]  what a narrowed date range leaves behind — one row, so
//                        the filtered chip is read against a visibly smaller
//                        list than the unfiltered state beside it.
//   [longestContent]     the layout ceiling — two full-length Beirut addresses
//                        and a seven-digit LBP amount, reviewed on the
//                        narrowest phone the app supports.
//
// NOTHING here touches the network. Every repository answers from a static
// list, throws, or never completes — the `CatalogNetworkGuard` both hosts
// install is a net, not the plan. There is no Dio, no GetIt and no
// `DioOrderRepository` on any path below.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';

// ─────────────────────────────────────────────────────────────────────────
// Repositories — three outcomes, no network
// ─────────────────────────────────────────────────────────────────────────

/// Answers every read from [orders], bucketed by [OrderRequestStatus.tab].
///
/// The bucketing is what the gateway's `status` filter does, and it is why the
/// Completed and Cancelled tabs of a populated state show their own (empty)
/// content rather than the Active rows a second and third time.
///
/// `hasMore` is always `false`: the screen's infinite scroll asks for page 2 as
/// soon as the viewport reaches the end of the list, and a fake that claimed
/// more pages would spin a dev surface forever.
///
/// The [range] argument is accepted and IGNORED — date filtering is server-side
/// (`GET /v1/requests?from=&to=`), so a fixture that re-implemented it would be
/// asserting the gateway's behaviour rather than the screen's. The filtered
/// state instead hands this fake the slice that a range already narrowed; see
/// [OrderHistoryScreenOrders.dateFilteredSlice].
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
///
/// It MUST throw [OrderRepositoryException] and nothing else: that is the only
/// type [OrderHistoryCubit] catches, so any other error escapes the cubit and
/// takes the surface down instead of rendering the error state this fake is
/// for. Failing on the FIRST read matters too — the cubit flips to
/// `OrderTabStatus.error` only on a cold load; a fake that succeeded once and
/// then threw would keep the list on screen under a transient snackbar.
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
///
/// Not a hypothetical: `OrderHistoryScreen.initState` posts `initialLoad()` for
/// the frame after mount, so every customer who opens the Delivery tab sees
/// this state for as long as `GET /v1/requests` takes. A [Completer] that is
/// never completed holds no timer and no subscription, so it settles under
/// `pumpAndSettle` like any static widget — the spinner it puts on screen does
/// not, which is why the preview that uses this fake mutes its ticker.
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

// ─────────────────────────────────────────────────────────────────────────
// Casts
// ─────────────────────────────────────────────────────────────────────────

/// The designed order lists, one per state.
///
/// Every cast prices its rows differently from every other cast, so a state
/// accidentally rewired to a neighbouring fixture shows a wrong number on
/// screen instead of looking plausible.
///
/// Timestamps are UTC and the card renders `createdAt.toLocal()` (SW-03), so
/// the date label moves with the reviewer's machine. Never pin it.
class OrderHistoryScreenOrders {
  const OrderHistoryScreenOrders._();

  /// The reference reading, verbatim from the Screen Catalog entry: two live
  /// requests at different points of the journey.
  ///
  /// `REQ-1038` carries a NULL `amountMinor` on purpose — T11 / SW-02, the
  /// defect where every history row read `$0.00` because a missing key was
  /// coerced to zero. The requests-list endpoint really does drop the amount
  /// for rows that are not settled yet, and an absent price is UNKNOWN: it must
  /// render the muted em-dash with an "Amount unavailable" a11y label. If this
  /// state ever shows two currency amounts, `hasKnownAmount` has broken.
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

  /// A read that SUCCEEDED and came back with zero rows.
  ///
  /// Worth its own name: "No orders yet" is also the exact surface a
  /// wrongly-scoped tab strands on (JEBV4-280 — a jeeber hitting the customer
  /// list got an empty page and this screen), so the empty state and that bug
  /// are indistinguishable by design.
  static const List<OrderSummary> none = <OrderSummary>[];

  /// What a narrowed date range leaves behind.
  ///
  /// The gateway applies `from`/`to` itself, so this is the RESULT of a filter
  /// rather than a list the fixture filters: one delivery on the selected day,
  /// at a price no other cast uses.
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
  ///
  /// `LBP 1,335,000.00` is a $15 delivery at the 2026 peg — not a synthetic
  /// number — and it is the same amount `OrderHistoryCard`'s own ceiling
  /// preview uses, so the row and the screen describe one card. Three squeezes
  /// meet on it and each fails differently: the header Row (an `Expanded` date
  /// beside a NON-flexible status chip), both address lines (`maxLines: 2` +
  /// ellipsis, so a real third line is silently lost) and the footer Row (the
  /// tier label in an `Expanded` beside an amount with no `Flexible` at all).
  ///
  /// The second row is deliberately short and carries a status this build has
  /// never heard of: `OrderRequestStatus.unknown` buckets into Active and
  /// renders the localized "In progress" rather than vanishing, which is what
  /// keeps a gateway-side status addition visible to the user and to QA.
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

/// The designed date range for the filtered state: a single calendar day.
///
/// Built through [OrderDateRange.forInclusiveDays] — the same constructor the
/// filter sheet uses — so `to` is the local midnight AFTER the picked day and
/// the range stays the half-open `[from, to)` the gateway expects. Nothing
/// renders either date; what the chip renders is the fact that a range is set
/// (`orderHistoryFilterActive`, "Date filter applied").
final OrderDateRange orderHistoryScreenFilterRange =
    OrderDateRange.forInclusiveDays(
  from: DateTime(2026, 6, 18),
  to: DateTime(2026, 6, 18),
);
