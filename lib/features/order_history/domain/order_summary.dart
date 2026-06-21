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

  /// Parses the gateway's lowercase snake_case status string.
  static OrderRequestStatus parse(String? raw) {
    switch (raw) {
      case 'pending':
        return OrderRequestStatus.pending;
      case 'matched':
        return OrderRequestStatus.matched;
      case 'picked_up':
        return OrderRequestStatus.pickedUp;
      case 'en_route':
        return OrderRequestStatus.enRoute;
      case 'delivered':
        return OrderRequestStatus.delivered;
      case 'cancelled':
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

  /// Minor units (e.g. piastres for LBP, cents for USD) to avoid float math.
  final int amountMinor;

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
