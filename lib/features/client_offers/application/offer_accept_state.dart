import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/offers_repository.dart';

enum OfferAcceptStatus { idle, submitting, succeeded, failed }

class OfferAcceptState extends Equatable {
  const OfferAcceptState({
    this.status = OfferAcceptStatus.idle,
    this.result,
    this.error,
    this.appFailure,
  });

  final OfferAcceptStatus status;

  final OfferAcceptResult? result;

  final OffersFailure? error;

  /// The classified failure behind [error].
  final AppFailure? appFailure;

  bool get isSubmitting => status == OfferAcceptStatus.submitting;

  /// These responses say the target can no longer be accepted. A repeated
  /// write cannot repair an expired request or an offer that is not pending.
  bool get canConfirm =>
      !isSubmitting &&
      status != OfferAcceptStatus.succeeded &&
      error != OffersFailure.requestExpired &&
      error != OffersFailure.requestNotOpen &&
      error != OffersFailure.offerNotPending &&
      appFailure is! UnauthorizedFailure &&
      appFailure is! ForbiddenFailure &&
      appFailure is! NotFoundFailure &&
      appFailure is! GoneFailure;

  OfferAcceptState copyWith({
    OfferAcceptStatus? status,
    OfferAcceptResult? result,
    bool clearResult = false,
    OffersFailure? error,
    AppFailure? appFailure,
    bool clearError = false,
  }) {
    return OfferAcceptState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? error : (error ?? this.error),
      appFailure: clearError ? appFailure : (appFailure ?? this.appFailure),
    );
  }

  @override
  List<Object?> get props => [status, result, error, appFailure];
}
