import 'submitted_offer.dart';

/// Source of the jeeber's submitted offers (the Pending-Response sub-tab of the
/// feed, JM-047/048). Kept a narrow interface so the feed view depends on the
/// contract, not Dio, and widget tests inject a scripted list without a network
/// round-trip (40_GUARDRAILS_ARCH).
abstract class SubmittedOffersRepository {
  /// Pull the offers this jeeber has submitted that are awaiting a customer
  /// decision. Backs `pending_offer_<index>` rows.
  /// Wire: `GET /offer-service/v1/offers?jeeberId=` filtered to `submitted`.
  Future<List<SubmittedOffer>> listSubmitted();

  /// Withdraw the offer with [offerId] (D15). Returns true on success so the
  /// row can be removed optimistically.
  /// Wire: `DELETE /offer-service/v1/offers/:offerId`.
  Future<bool> withdraw(String offerId);
}
