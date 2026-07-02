import 'package:equatable/equatable.dart';

/// Domain contract for submitting a Jeeber offer.
///
/// Endpoint (LIVE gateway, iter6 offer-405 fix — `RequestOffersController`
/// `POST /requests/{requestId}/offers`, body `{ fee, etaMinutes, note? }`):
///   → 201 OfferDto `{ id, requestId, jeeberId, status, fee, etaMinutes, … }`
///         on success. `id` is the offerId; the body carries NO conversationId
///         (the jeeber is seated on the request's conversation server-side,
///         keyed by requestId), so the result's conversationId falls back to
///         the requestId — consistent with the chat-contract rewrite (PR #69).
///   → 402 {needed, available, currency} when the wallet can't cover the 10%
///         reserve (O1, JM-046) — NOT a generic error; routes to the
///         insufficient-balance sheet (42_GUARDRAILS_MOCK §5.1)
///   → 404/409/410                    request gone / no longer accepting offers
///   → 422                            offer-service rejected the payload
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

/// Shape returned by a successful `POST /requests/{requestId}/offers` call.
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

  /// The request was already claimed / cancelled before the offer landed, OR
  /// the gateway reports `request-not-open-for-offers` (409) — the auction is
  /// closed for this jeeber, so the view bounces back to the feed.
  requestGone,

  /// sprint-009: 409 with the offer-cap discriminator — this jeeber already has
  /// the maximum live offers (20-offer cap). UNLIKE [requestGone] this is a
  /// per-jeeber throttle, not a dead request: the composer STAYS put and shows a
  /// distinct "you've reached the offer limit" message so the jeeber can
  /// withdraw an existing offer and retry, rather than being bounced.
  offerCapReached,

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
