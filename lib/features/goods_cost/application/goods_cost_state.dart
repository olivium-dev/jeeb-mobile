import 'package:equatable/equatable.dart';

import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

/// Submit lifecycle for the goods-cost record action, kept separate from the
/// best-effort currency read so a record failure shows an inline error without
/// tearing down the form. `succeeded` is the one-shot the screen listens for to
/// pop with the gateway-confirmed [GoodsCost].
enum GoodsCostSubmitStatus { idle, inFlight, succeeded, failed }

class GoodsCostState extends Equatable {
  const GoodsCostState({
    this.currency,
    this.submitStatus = GoodsCostSubmitStatus.idle,
    this.submitError,
    this.recorded,
  });

  /// Gateway-authoritative currency for the entry-field label. `null` until the
  /// best-effort read resolves (or stays null if it failed — the label
  /// degrades to a neutral "Amount" rather than blocking entry).
  final String? currency;

  final GoodsCostSubmitStatus submitStatus;
  final GoodsCostFailure? submitError;

  /// The gateway-confirmed record, set on success.
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
