import 'package:equatable/equatable.dart';

/// One offer the jeeber has SUBMITTED that is awaiting a customer decision —
/// the row data behind the feed's Pending-Response sub-tab (JM-047/048).
///
/// Distinct from [DeliveryRequest] (an INCOMING request the jeeber can offer
/// on): a [SubmittedOffer] is the jeeber's OWN bid, so it carries the price
/// and ETA the jeeber quoted (not the request's potential earnings) plus the
/// reserve held when it was sent (D1). Sourced from
/// `GET /offer-service/v1/offers?jeeberId=` (JM-048 AC3 mock contract).
class SubmittedOffer extends Equatable {
  const SubmittedOffer({
    required this.id,
    required this.requestId,
    required this.price,
    required this.currency,
    this.etaMinutes,
    this.note,
  });

  /// Stable offer id. Used for the `pending_offer_<index>` row Semantics and
  /// the `DELETE /offer-service/v1/offers/:offerId` withdraw target (D15).
  final String id;

  /// The request this offer was placed against (lets the row link back to the
  /// originating delivery request when the detail screen lands).
  final String requestId;

  /// The price the jeeber quoted (cash-on-delivery, D11). Plain amount; the
  /// row formats it with [currency].
  final double price;

  /// ISO 4217 currency code for [price] (e.g. `USD`).
  final String currency;

  /// The ETA the jeeber committed to, in minutes. `null` hides the ETA line.
  final int? etaMinutes;

  /// Optional free-text note the jeeber attached to the offer.
  final String? note;

  @override
  List<Object?> get props => [id, requestId, price, currency, etaMinutes, note];
}
