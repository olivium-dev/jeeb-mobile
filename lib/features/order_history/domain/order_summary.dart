import 'package:equatable/equatable.dart';

/// The three buckets the history screen renders as tabs.
///
/// `active` is the umbrella state for any request still in-flight (pending,
/// matched, picked_up, en_route — the gateway returns them under the same
/// `status` filter value so the client doesn't need to enumerate the full
/// request state machine here).
enum OrderHistoryTab { active, completed, cancelled }

/// Wire-level status values returned by `GET /v1/requests`.
///
/// The full state machine lives in jeeb-gateway; this enum only enumerates
/// the values the order-history screen needs to render. Anything outside
/// these maps to [OrderRequestStatus.unknown] so a future state added on the
/// backend does not crash the mobile build.
enum OrderRequestStatus {
  pending,
  matched,
  pickedUp,
  enRoute,
  delivered,
  cancelled,
  disputed,
  unknown;

  /// Parses a gateway status string — BOTH the canonical V3 vocabulary
  /// (`Ordered → Picked → InTransit → AtDoor → Done`, plus `accepted` for
  /// an offer accepted before pickup) AND the legacy snake_case aliases
  /// (`picked_up`, `en_route`, ...). Run-22 P1-B / lane item 6: the old
  /// parser only understood the legacy lowercase names, so every canonical
  /// status fell into [unknown] — a `Done` order surfaced under Active and
  /// the Completed/Cancelled tabs never matched anything canonical.
  ///
  /// Comparison is case-insensitive with underscores stripped, so
  /// `InTransit`, `IN_TRANSIT`, `in_transit` and `intransit` all resolve.
  static OrderRequestStatus parse(String? raw) {
    final normalized =
        (raw ?? '').trim().toLowerCase().replaceAll('_', '');
    switch (normalized) {
      // Auction / not-yet-assigned.
      case 'pending':
      case 'searching':
      case 'offered':
        return OrderRequestStatus.pending;
      // Assigned but nothing picked up yet — the accepted-pre-pickup state
      // MUST bucket as active/In Progress (run-22 P1-B).
      case 'accepted':
      case 'assigned':
      case 'matched':
      case 'ordered':
        return OrderRequestStatus.matched;
      case 'picked':
      case 'pickedup':
        return OrderRequestStatus.pickedUp;
      case 'intransit':
      case 'enroute':
      case 'atdoor':
      case 'headingoff':
        return OrderRequestStatus.enRoute;
      // Canonical terminal `Done` + tolerant delivered/completed aliases.
      case 'done':
      case 'delivered':
      case 'completed':
      case 'rated':
        return OrderRequestStatus.delivered;
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return OrderRequestStatus.cancelled;
      case 'disputed':
        return OrderRequestStatus.disputed;
      default:
        return OrderRequestStatus.unknown;
    }
  }

  /// Which history tab this status belongs to. `unknown` lands in `active`
  /// so new backend states are visible to the user (and to QA) rather than
  /// being silently dropped.
  OrderHistoryTab get tab {
    switch (this) {
      case OrderRequestStatus.delivered:
        return OrderHistoryTab.completed;
      case OrderRequestStatus.cancelled:
      case OrderRequestStatus.disputed:
        return OrderHistoryTab.cancelled;
      case OrderRequestStatus.pending:
      case OrderRequestStatus.matched:
      case OrderRequestStatus.pickedUp:
      case OrderRequestStatus.enRoute:
      case OrderRequestStatus.unknown:
        return OrderHistoryTab.active;
    }
  }
}

/// Tier the request was booked at. Mirrors the five tiers defined in
/// jeeb-gateway. Unknown values fall back to [OrderTier.standard] so the
/// card still has an icon to render.
enum OrderTier {
  flash,
  express,
  standard,
  onTheWay,
  eco;

  static OrderTier parse(String? raw) {
    switch (raw) {
      case 'flash':
        return OrderTier.flash;
      case 'express':
        return OrderTier.express;
      case 'standard':
        return OrderTier.standard;
      case 'on_the_way':
      case 'onTheWay':
        return OrderTier.onTheWay;
      case 'eco':
        return OrderTier.eco;
      default:
        return OrderTier.standard;
    }
  }
}

/// One row in the order-history list. Pure domain object — no formatting,
/// no Material types. The presentation layer is responsible for turning
/// these into the on-screen card.
class OrderSummary extends Equatable {
  const OrderSummary({
    required this.id,
    required this.createdAt,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.tier,
    required this.amountMinor,
    required this.currency,
  });

  /// Server-issued request id (UUID or short code).
  final String id;

  /// When the request was created. Used for the date label and date-range
  /// filtering; always in UTC, the presentation layer renders in local TZ.
  final DateTime createdAt;

  final String pickupAddress;
  final String dropoffAddress;
  final OrderRequestStatus status;
  final OrderTier tier;

  /// Amount in minor units (e.g. piastres for LBP, cents for USD) to avoid
  /// float math.
  ///
  /// NULL when the gateway did not surface a usable amount. An absent price is
  /// UNKNOWN — it must never be rendered as a fabricated `$0.00` (T11 / SW-02:
  /// every history row read `$0.00`, even the completed $12 order). This mirrors
  /// the receipt's `cashAmount` contract (run-22 P1-A): the requests-list
  /// endpoint drops the amount for some rows, and a missing key is not a zero.
  final int? amountMinor;

  /// True when the gateway surfaced a real, positive amount. Zero/negative wire
  /// values are treated as unknown too — a priced request is never actually
  /// worth 0, so a 0 here means enrichment broke (same rule as the receipt).
  bool get hasKnownAmount => (amountMinor ?? 0) > 0;

  /// ISO 4217 currency code.
  final String currency;

  @override
  List<Object?> get props => [
        id,
        createdAt,
        pickupAddress,
        dropoffAddress,
        status,
        tier,
        amountMinor,
        currency,
      ];
}

/// Page of orders returned by the repository. `hasMore` is the only signal
/// the cubit uses to decide whether to keep paging — the server's total
/// count is intentionally not surfaced here because it makes the cubit
/// brittle to schema drift.
class OrderPage extends Equatable {
  const OrderPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<OrderSummary> items;
  final int page;
  final bool hasMore;

  @override
  List<Object?> get props => [items, page, hasMore];
}

/// Inclusive date range used by the filter sheet. Both ends are optional so
/// "from yesterday" and "up to a specific date" are both expressible.
class OrderDateRange extends Equatable {
  const OrderDateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => from == null && to == null;

  @override
  List<Object?> get props => [from, to];
}
