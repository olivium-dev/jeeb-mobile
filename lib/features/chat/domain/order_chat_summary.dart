import 'package:equatable/equatable.dart';

/// Locked authoritative-price snapshot for the pinned summary strip on the
/// accepted order-chat (JM-025 AC2, D71/D11). The values are the *locked*
/// figures captured at accept time — the UI never recomputes them; it renders
/// what the delivery/offer rows already hold.
///
/// Sourced (via [OrderChatSummaryRepository]) from the accepted delivery +
/// its request: price from the accepted amount, ETA from the winning offer,
/// tier + order reference (`displayId`) from the request, and the winning
/// Jeeber's name/rating from the conversation winner.
///
/// Cash-on-delivery is the only payment model (D11): the strip always carries
/// the "Pay cash on delivery" reminder — there is no in-app charge.
class OrderChatSummary extends Equatable {
  const OrderChatSummary({
    required this.deliveryId,
    this.requestId = '',
    this.priceLabel = '',
    this.jeeberName = '',
    this.rating = 0,
    this.etaMinutes,
    this.tierId = '',
    this.orderRef = '',
    this.statusId = '',
    this.description = '',
  });

  /// The accepted delivery this summary belongs to. Used as the
  /// `order-summary` / `order-tracking` route id.
  final String deliveryId;

  /// The backing request id (mock convention: `deliveryId == accepted
  /// request id`). Empty when the summary was resolved from a delivery row
  /// that carried no request reference.
  final String requestId;

  /// Pre-formatted locked price (e.g. `$9.00`). Empty when the source row had
  /// no amount — the strip then hides the price chip rather than show `0`.
  final String priceLabel;

  /// Winning Jeeber display name. Empty falls back to the chat counterpart.
  final String jeeberName;

  /// Winning Jeeber rating (0 when unrated / cold-start).
  final double rating;

  /// Locked ETA in minutes from the winning offer. Null hides the ETA chip.
  final int? etaMinutes;

  /// Tier id (`flash`/`express`/`standard`/`on-the-way`/`eco`). Empty hides
  /// the tier chip. The UI maps the id to a localized label.
  final String tierId;

  /// Human order reference (`ORD-…`, the request `displayId`). Empty hides the
  /// ref chip.
  final String orderRef;

  /// Delivery lifecycle status as it arrives on the wire (the delivery row's
  /// `status`, e.g. `Ordered`/`matched`/`picked_up`/`InTransit`/`Done`). The
  /// UI maps it onto the canonical `deliveryStage*` vocabulary; empty means
  /// the source row carried no status (the strip falls back to the accepted
  /// stage, since it only renders on an accepted order).
  final String statusId;

  /// P3 (b01-20260725): the INITIAL REQUIREMENT — the free text the customer
  /// typed at compose (`DeliveryRequestDto.description`, mirrored from the
  /// request row). Rendered verbatim in the pinned strip for BOTH parties.
  /// Empty when the source row carried none — the strip then hides the row
  /// entirely (never an empty box or a "Pending" filler).
  final String description;

  bool get hasPrice => priceLabel.isNotEmpty;
  bool get hasEta => etaMinutes != null;
  bool get hasTier => tierId.isNotEmpty;
  bool get hasRef => orderRef.isNotEmpty;
  bool get hasStatus => statusId.isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        deliveryId,
        requestId,
        priceLabel,
        jeeberName,
        rating,
        etaMinutes,
        tierId,
        orderRef,
        statusId,
        description,
      ];
}

/// Typed failure surface for the order-chat summary fetch. The screen maps
/// these to "summary unavailable" (the strip simply doesn't render) — a
/// summary fetch never blocks the chat thread itself.
enum OrderChatSummaryFailure { notFound, network, unknown }

class OrderChatSummaryException implements Exception {
  const OrderChatSummaryException(this.failure, [this.message]);
  final OrderChatSummaryFailure failure;
  final String? message;
}

/// Reads the locked order summary for an accepted order-chat. PURE domain
/// contract — no Dio/Flutter/GetIt imports. Implemented over the
/// delivery/offer services by [DioOrderChatSummaryRepository].
abstract class OrderChatSummaryRepository {
  /// Resolve the pinned summary for [deliveryId] (the accepted delivery /
  /// request). Throws [OrderChatSummaryException] on a transport/parse error.
  Future<OrderChatSummary> fetchSummary(String deliveryId);
}
