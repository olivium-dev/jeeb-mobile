import 'package:equatable/equatable.dart';

import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

enum GoodsCostSubmitStatus { idle, inFlight, succeeded, failed }

class GoodsCostState extends Equatable {
  const GoodsCostState({
    this.currency,
    this.submitStatus = GoodsCostSubmitStatus.idle,
    this.submitError,
    this.recorded,
  });

  final String? currency;

  final GoodsCostSubmitStatus submitStatus;
  final GoodsCostFailure? submitError;

  final GoodsCost? recorded;

  bool get isSubmitting => submitStatus == GoodsCostSubmitStatus.inFlight;

  GoodsCostState copyWith({
    String? currency,
    GoodsCostSubmitStatus? submitStatus,
    GoodsCostFailure? submitError,
    GoodsCost? recorded,
    bool clearSubmitError = false,
  }) =>
      GoodsCostState(
        currency: currency ?? this.currency,
        submitStatus: submitStatus ?? this.submitStatus,
        submitError: clearSubmitError ? null : (submitError ?? this.submitError),
        recorded: recorded ?? this.recorded,
      );

  @override
  List<Object?> get props => [currency, submitStatus, submitError, recorded];
}
