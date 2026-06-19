import 'package:equatable/equatable.dart';

/// Authoritative, pinned snapshot of an accepted order (JM-031, D11/D71/D6).
///
/// This is the single source of truth the [OrderSummaryPinned] header widget
/// renders in BOTH `order-chat` (JM-025) and `order-tracking` (JM-032). The
/// values are locked at accept time — the customer never re-negotiates after
/// accepting (D71) — and the price is the COD amount the customer pays the
/// Jeeber in cash on delivery (D11): NO commission/finance line is ever shown
/// on this customer-facing surface.
///
/// Pure Dart value object — no Flutter / Dio / GetIt. Built in the data layer
/// from the delivery + request (+ best-effort offer/user) mock payloads.
class OrderSummary extends Equatable {
  const OrderSummary({
    required this.deliveryId,
    required this.requestId,
    required this.conversationId,
    required this.price,
    required this.currency,
    required this.jeeberName,
    required this.tier,
    this.jeeberRating,
    this.jeeberRatingCount,
    this.etaMinutes,
    this.itemSummary,
    this.jeeberAvatarUrl,
  });

  /// The accepted delivery/order id. Drives the `order_summary_track` CTA
  /// (`/orders/:id/tracking`).
  final String deliveryId;

  /// The originating request id. The chat CTA resolves the conversation from
  /// this when [conversationId] is empty (mock convention: `deliveryId ==
  /// accepted-request-id`).
  final String requestId;

  /// The 1:1 conversation id for the accepted order. Empty when the payload
  /// did not surface one; the `order_summary_open_chat` CTA then falls back to
  /// the delivery/request id (the `/chat/:id` route resolves either).
  final String conversationId;

  /// Accepted COD price the customer pays in cash on delivery (D11). Whole or
  /// decimal currency units; formatted to 2dp at the widget boundary.
  final double price;

  /// ISO currency code for [price] (e.g. `USD`).
  final String currency;

  /// Display name of the matched Jeeber. Never empty — the parser falls back
  /// to the jeeber id when the payload omits the name.
  final String jeeberName;

  /// Tier id/label of the accepted order (e.g. `express`). Mapped to localized
  /// copy at the widget boundary.
  final String tier;

  /// Jeeber lifetime average rating (0–5). Null hides the rating chip (D6:
  /// cold-start jeebers may have no score yet).
  final double? jeeberRating;

  /// Total ratings the average is computed from. Null/0 renders no count.
  final int? jeeberRatingCount;

  /// Estimated minutes to delivery. Null hides the ETA value (renders a
  /// pending dash) rather than a misleading "0 min".
  final int? etaMinutes;

  /// One-line summary of what was ordered (the request/delivery title). Null
  /// hides the item line.
  final String? itemSummary;

  /// Optional Jeeber avatar (CDN url). Falls back to initials at the boundary.
  final String? jeeberAvatarUrl;

  /// True once a rating is present and computed from at least one review, so
  /// the widget can decide whether to mount the rating chip (D6/D59).
  bool get hasRating => jeeberRating != null && (jeeberRatingCount ?? 0) > 0;

  @override
  List<Object?> get props => [
        deliveryId,
        requestId,
        conversationId,
        price,
        currency,
        jeeberName,
        tier,
        jeeberRating,
        jeeberRatingCount,
        etaMinutes,
        itemSummary,
        jeeberAvatarUrl,
      ];
}
