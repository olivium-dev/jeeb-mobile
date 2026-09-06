import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';

///         insufficient-balance sheet (42_GUARDRAILS_MOCK §5.1)
abstract class OfferSubmissionRepository {
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  });
}

/// Optional capability a repository may add: submit under a caller-owned
/// idempotency key so a retried draft cannot double-post (NET-12).
abstract class IdempotentOfferSubmission {
  Future<OfferSubmissionResult> submitOfferIdempotent({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    required String idempotencyKey,
    String? note,
  });
}

class OfferSubmissionResult {
  const OfferSubmissionResult({
    required this.offerId,
    required this.conversationId,
  });

  final String offerId;
  final String conversationId;
}

enum OfferSubmissionFailure {
  invalidInput,

  requestGone,

  insufficientBalance,

  /// 409 `offer-already-exists` — this Jeeber already has a live bid.
  duplicateOffer,

  /// 409 `offer-out-of-range` — the fee sits outside the accepted band.
  outOfRange,

  /// 409 `same-delivery-role-violation` — bidding on your own request.
  sameRoleViolation,

  /// 409 `request-not-open-for-offers` — the request stopped taking offers.
  requestNotOpen,

  /// 400/422 `offer-fee-too-low` — the price field is at fault.
  feeTooLow,

  /// 400/422 `offer-eta-invalid` — the ETA field is at fault.
  etaInvalid,

  /// 400/422 `offer-note-too-long` — the note field is at fault.
  noteTooLong,

  network,

  server,
}

/// The 402 figures. Every field is optional: a malformed body must never
/// fabricate a `$0.00` needed-vs-available pair (UX-15).
class InsufficientBalanceInfo extends Equatable {
  const InsufficientBalanceInfo({this.needed, this.available, this.currency});

  final double? needed;

  final double? available;

  final String? currency;

  @override
  List<Object?> get props => [needed, available, currency];
}

class OfferSubmissionException implements Exception {
  const OfferSubmissionException(this.failure, {this.cause, this.balance});

  final OfferSubmissionFailure failure;

  /// Diagnostics + the screen's copy fallback. Never rendered verbatim.
  final AppFailure? cause;

  final InsufficientBalanceInfo? balance;

  @override
  String toString() => 'OfferSubmissionException(${failure.name})';
}
