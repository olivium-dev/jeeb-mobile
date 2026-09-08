import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

enum GoodsCostSubmitStatus { idle, inFlight, succeeded, failed }

class GoodsCostState extends Equatable {
  const GoodsCostState({
    this.currency,
    this.currencyUnavailable = false,
    this.submitStatus = GoodsCostSubmitStatus.idle,
    this.submitError,
    this.failure,
    this.recorded,
  });

  final String? currency;

  /// The currency read failed, so the field renders its neutral label AND an
  /// inline retry — the Jeeber is told the unit is unknown (LR-29).
  final bool currencyUnavailable;

  final GoodsCostSubmitStatus submitStatus;
  final GoodsCostFailure? submitError;

  /// The classified failure behind [submitError], for the copy family.
  final AppFailure? failure;

  final GoodsCost? recorded;

  bool get isSubmitting => submitStatus == GoodsCostSubmitStatus.inFlight;

  GoodsCostState copyWith({
    String? currency,
    bool? currencyUnavailable,
    GoodsCostSubmitStatus? submitStatus,
    GoodsCostFailure? submitError,
    AppFailure? failure,
    GoodsCost? recorded,
    bool clearSubmitError = false,
  }) => GoodsCostState(
    currency: currency ?? this.currency,
    currencyUnavailable: currencyUnavailable ?? this.currencyUnavailable,
    submitStatus: submitStatus ?? this.submitStatus,
    submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    failure: clearSubmitError ? null : (failure ?? this.failure),
    recorded: recorded ?? this.recorded,
  );

  @override
  List<Object?> get props => [
    currency,
    currencyUnavailable,
    submitStatus,
    submitError,
    failure,
    recorded,
  ];
}
