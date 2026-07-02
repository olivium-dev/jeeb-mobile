import 'package:equatable/equatable.dart';

/// Lifecycle state of a jeeber's submitted offer (sprint-009 offer-lifecycle).
///
/// The gateway's `GET /v1/offers?jeeberId=` returns a `status` string per offer;
/// the two terminal customer decisions (`accepted` / `lost`) now surface in the
/// pending-offers list as badges instead of being filtered out — the jeeber
/// sees the outcome of every bid, not only the ones still open.
enum OfferStatus {
  /// Awaiting the customer's decision — the row shows Withdraw.
  submitted,

  /// The customer accepted THIS offer (`offer_accepted` push / status
  /// `accepted`). Terminal — no Withdraw; badge reads "Accepted".
  accepted,

  /// The customer accepted someone else's offer (`offer_lost` push / status
  /// `lost`/`rejected`). Terminal — no Withdraw; badge reads "Not selected".
  lost;

  /// Maps a wire `status` string (offer-service / gateway) to a lifecycle
  /// state. Unknown/absent values fall back to [submitted] so a legacy row
  /// still renders as awaiting rather than vanishing.
  static OfferStatus fromWire(String? raw) {
    switch (raw?.toLowerCase().replaceAll('_', '')) {
      case 'accepted':
      case 'accept':
        return OfferStatus.accepted;
      case 'lost':
      case 'rejected':
      case 'declined':
      case 'notselected':
        return OfferStatus.lost;
      case 'submitted':
      case 'pending':
      case 'open':
      case 'live':
      default:
        return OfferStatus.submitted;
    }
  }

  bool get isTerminal => this != OfferStatus.submitted;
}

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
    this.status = OfferStatus.submitted,
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

  /// Lifecycle state (sprint-009). Defaults to [OfferStatus.submitted] so
  /// existing call sites and fixtures keep their prior "awaiting" semantics.
  final OfferStatus status;

  /// Returns a copy with [status] replaced — used to flip a row's badge in
  /// place when an `offer_accepted` / `offer_lost` push lands before the next
  /// authoritative re-pull.
  SubmittedOffer copyWith({OfferStatus? status}) {
    return SubmittedOffer(
      id: id,
      requestId: requestId,
      price: price,
      currency: currency,
      etaMinutes: etaMinutes,
      note: note,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props =>
      [id, requestId, price, currency, etaMinutes, note, status];
}
