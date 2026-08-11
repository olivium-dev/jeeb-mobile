import 'package:equatable/equatable.dart';

/// Locked authoritative-price snapshot for pinned summary strip on accepted order-chat (JM-025 AC2).
/// Values captured at accept time; sourced from accepted delivery + request + winning offer/Jeeber.
/// Cash-on-delivery only; strip always carries "Pay cash on delivery" reminder.
class OrderChatSummary extends Equatable {
  const OrderChatSummary({
    required this.deliveryId,
    this.requestId = '',
    this.priceLabel = '',
    this.jeeberName = '',
    this.jeeberAvatarUrl = '',
    this.clientName = '',
    this.clientAvatarUrl = '',
    this.rating = 0,
    this.etaMinutes,
    this.tierId = '',
    this.orderRef = '',
    this.statusId = '',
    this.description = '',
  });

  /// Accepted delivery this summary belongs to; route id for order-summary/tracking.
  final String deliveryId;

  /// Backing request id (mock: deliveryId == accepted request id). Empty if delivery carried no reference.
  final String requestId;

  /// Pre-formatted locked price (e.g. `$9.00`). Empty hides price chip.
  final String priceLabel;

  /// Winning Jeeber display name. Empty falls back to chat counterpart.
  final String jeeberName;

  /// Winning Jeeber avatar (absolute, loadable). Empty falls back to the letter placeholder.
  final String jeeberAvatarUrl;

  /// Ordering client's display name — the JEEBER leg's counterpart. Empty falls back to the role generic.
  final String clientName;

  /// Ordering client's avatar (absolute, loadable). Empty falls back to the letter placeholder.
  final String clientAvatarUrl;

  /// Winning Jeeber rating (0 when unrated / cold-start).
  final double rating;

  /// Locked ETA in minutes from winning offer. Null hides ETA chip.
  final int? etaMinutes;

  /// Tier id (`flash`/`express`/`standard`/`on-the-way`/`eco`). Empty hides chip; UI maps id to label.
  final String tierId;

  /// Human order reference (`ORD-…`, the request `displayId`). Empty hides chip.
  final String orderRef;

  /// Delivery lifecycle status (e.g. `Ordered`/`matched`/`picked_up`/`InTransit`/`Done`).
  /// UI maps to canonical `deliveryStage*` vocabulary; empty falls back to accepted stage.
  final String statusId;

  /// P3 initial requirement: free text customer typed at compose. Rendered verbatim in pinned strip.
  /// Empty hides row entirely (never shows empty box).
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
        jeeberAvatarUrl,
        clientName,
        clientAvatarUrl,
        rating,
        etaMinutes,
        tierId,
        orderRef,
        statusId,
        description,
      ];
}

/// Counterpart identity picked by viewer role — the ONE place the leg is chosen,
/// so a header photo, header name and rating screen can never disagree.
extension OrderChatSummaryCounterpart on OrderChatSummary {
  /// The OTHER party's display name; empty when unset.
  String counterpartName({required bool viewerIsJeeber}) =>
      viewerIsJeeber ? clientName : jeeberName;

  /// The OTHER party's avatar; null (letter placeholder) when unset.
  String? counterpartAvatarUrl({required bool viewerIsJeeber}) {
    final url = viewerIsJeeber ? clientAvatarUrl : jeeberAvatarUrl;
    return url.isEmpty ? null : url;
  }
}

/// Typed failure surface for order-chat summary fetch. Screen maps these to
/// "summary unavailable" (strip doesn't render); fetch never blocks chat thread.
enum OrderChatSummaryFailure { notFound, network, unknown }

class OrderChatSummaryException implements Exception {
  const OrderChatSummaryException(this.failure, [this.message]);
  final OrderChatSummaryFailure failure;
  final String? message;
}

/// Reads locked order summary for accepted order-chat. PURE domain contract (no Dio/Flutter/GetIt).
abstract class OrderChatSummaryRepository {
  /// Resolve pinned summary for [deliveryId] (accepted delivery/request).
  /// Throws [OrderChatSummaryException] on transport/parse error.
  Future<OrderChatSummary> fetchSummary(String deliveryId);
}
