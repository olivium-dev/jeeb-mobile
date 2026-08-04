import 'package:equatable/equatable.dart';

import '../domain/offers_repository.dart';

enum OfferAcceptStatus { idle, submitting, succeeded, failed }

class OfferAcceptState extends Equatable {
  const OfferAcceptState({
    this.status = OfferAcceptStatus.idle,
    this.result,
    this.error,
  });

  final OfferAcceptStatus status;

  final OfferAcceptResult? result;

  final OffersFailure? error;

  bool get isSubmitting => status == OfferAcceptStatus.submitting;

  OfferAcceptState copyWith({
    OfferAcceptStatus? status,
    OfferAcceptResult? result,
    bool clearResult = false,
    OffersFailure? error,
    bool clearError = false,
  }) {
    return OfferAcceptState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, result, error];
}
