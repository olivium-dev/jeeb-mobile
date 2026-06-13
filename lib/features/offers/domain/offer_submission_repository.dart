/// Domain contract for submitting a Jeeber offer.
///
/// Endpoint verified against Mockoon :3055 (useMockPrefixes=false):
///   POST /v1/offers  body {requestId, priceUsd, etaMinutes, note}
///   → 200 {offerId, conversationId}  on success
///   → 409                            when the request was already claimed
///   → 422                            client-side validation failure (echo)
abstract class OfferSubmissionRepository {
  /// Submit an offer for [requestId].
  ///
  /// Returns [OfferSubmissionResult] on success.
  /// Throws [OfferSubmissionException] on failure.
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  });
}

/// Shape returned by a successful POST /v1/offers call.
class OfferSubmissionResult {
  const OfferSubmissionResult({
    required this.offerId,
    required this.conversationId,
  });

  final String offerId;
  final String conversationId;
}

/// Typed failure cases for offer submission.
enum OfferSubmissionFailure {
  /// Price ≤ 0 or ETA outside tier window — blocked client-side.
  invalidInput,

  /// The request was already claimed / cancelled before the offer landed.
  requestGone,

  /// Network unreachable.
  network,

  /// Any other 4xx / 5xx response.
  server,
}

class OfferSubmissionException implements Exception {
  const OfferSubmissionException(this.failure, [this.message]);

  final OfferSubmissionFailure failure;
  final String? message;

  @override
  String toString() =>
      'OfferSubmissionException(${failure.name}${message == null ? '' : ': $message'})';
}
