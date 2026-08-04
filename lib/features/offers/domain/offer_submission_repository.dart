import 'package:equatable/equatable.dart';

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

  network,

  server,
}

class InsufficientBalanceInfo extends Equatable {
  const InsufficientBalanceInfo({
    required this.needed,
    required this.available,
    required this.currency,
  });

  final double needed;

  final double available;

  final String currency;

  @override
  List<Object?> get props => [needed, available, currency];
}

class OfferSubmissionException implements Exception {
  const OfferSubmissionException(this.failure, {this.message, this.balance});

  final OfferSubmissionFailure failure;
  final String? message;

  final InsufficientBalanceInfo? balance;

  @override
  String toString() =>
      'OfferSubmissionException(${failure.name}${message == null ? '' : ': $message'})';
}
