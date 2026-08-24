import 'package:equatable/equatable.dart';

/// Wallet-guard ProblemDetails `type` URIs (CONTRACT §2 E1-E5, E7).
/// Matched by exact equality after trim only — never lowercase/substring.
const String kWalletGuardTypeInsufficientBalance =
    'https://jeeb.dev/errors/insufficient-wallet-balance';
const String kWalletGuardTypeOfferLiveLimitReached =
    'https://jeeb.dev/errors/offer-live-limit-reached';
const String kWalletGuardTypeHolderUnresolved =
    'https://jeeb.dev/errors/wallet-holder-unresolved';
const String kWalletGuardTypeFeeUnresolvable =
    'https://jeeb.dev/errors/offer-fee-unresolvable';
const String kWalletGuardTypeExposureUnresolvable =
    'https://jeeb.dev/errors/offer-exposure-unresolvable';
const String kWalletGuardTypeOfferJeeberInsufficientBalance =
    'https://jeeb.dev/errors/offer-jeeber-insufficient-balance';

/// `Offers:MaxLiveOffersPerJeeber` default when the 409 omits `limit`.
const int kDefaultMaxLiveOffersFallback = 20;

///         insufficient-balance sheet (42_GUARDRAILS_MOCK §5.1)
abstract class OfferSubmissionRepository {
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
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

  offerCapReached,

  insufficientBalance,

  holderUnresolved,

  feeUnresolvable,

  exposureUnresolvable,

  network,

  server,
}

class InsufficientBalanceInfo extends Equatable {
  const InsufficientBalanceInfo({
    required this.needed,
    required this.available,
    required this.currency,
    this.thisOffer,
    this.outstanding,
  });

  final double needed;

  final double available;

  final String currency;

  /// Aggregate breakdown (CONTRACT E1); null when the body omits them.
  final double? thisOffer;

  final double? outstanding;

  @override
  List<Object?> get props =>
      [needed, available, currency, thisOffer, outstanding];
}

/// `limit`/`live` from the 409 offer-live-limit-reached body; null when absent.
class OfferCapInfo extends Equatable {
  const OfferCapInfo({this.limit, this.live});

  final int? limit;

  final int? live;

  @override
  List<Object?> get props => [limit, live];
}

class OfferSubmissionException implements Exception {
  const OfferSubmissionException(
    this.failure, {
    this.message,
    this.balance,
    this.capInfo,
  });

  final OfferSubmissionFailure failure;
  final String? message;

  final InsufficientBalanceInfo? balance;

  final OfferCapInfo? capInfo;

  @override
  String toString() =>
      'OfferSubmissionException(${failure.name}${message == null ? '' : ': $message'})';
}
