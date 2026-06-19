import 'package:equatable/equatable.dart';

/// Domain contract for submitting a Jeeber offer.
///
/// Endpoint verified against the mock gateway (`/v1/offers` → :4010
/// `/offer-service/v1/offers`, `MockGatewayClient`):
///   → 201 {offerId, conversationId, …} on success (10% reserved, D1)
///   → 402 {needed, available, currency} when the wallet can't cover the 10%
///         reserve (O1, JM-046) — NOT a generic error; routes to the
///         insufficient-balance sheet (42_GUARDRAILS_MOCK §5.1)
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

  /// HTTP 402 (O1) — the wallet can't cover the 10% reserve. NOT a generic
  /// error: the cubit surfaces the insufficient-balance sheet (JM-046) carrying
  /// the [OfferSubmissionException.balance] amounts. Decisions D43/D1/D92/D93.
  insufficientBalance,

  /// Network unreachable.
  network,

  /// Any other 4xx / 5xx response.
  server,
}

/// The needed-vs-available figures a 402 carries (O1: `{needed, available,
/// currency}`). Surfaced verbatim on the JM-046 sheet (`insufficient_balance_*`
/// amounts). PURE data — no Flutter/Dio.
class InsufficientBalanceInfo extends Equatable {
  const InsufficientBalanceInfo({
    required this.needed,
    required this.available,
    required this.currency,
  });

  /// The reserve the offer needs (10% of price, D1) — `needed` in the 402 body.
  final double needed;

  /// The Jeeber's spendable balance — `available` in the 402 body.
  final double available;

  /// ISO currency code from the 402 body (e.g. `USD`).
  final String currency;

  @override
  List<Object?> get props => [needed, available, currency];
}

class OfferSubmissionException implements Exception {
  const OfferSubmissionException(this.failure, {this.message, this.balance});

  final OfferSubmissionFailure failure;
  final String? message;

  /// Set only when [failure] == [OfferSubmissionFailure.insufficientBalance] —
  /// the parsed 402 `{needed, available, currency}` (O1). Null otherwise.
  final InsufficientBalanceInfo? balance;

  @override
  String toString() =>
      'OfferSubmissionException(${failure.name}${message == null ? '' : ': $message'})';
}
