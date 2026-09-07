import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../../kyc/domain/kyc_submission.dart';

enum OfferKycGatePhase { loading, ready, error }

class OfferKycGateState extends Equatable {
  const OfferKycGateState({
    this.phase = OfferKycGatePhase.loading,
    this.status = KycStatus.notSubmitted,
    this.failure,
  });

  final OfferKycGatePhase phase;

  /// The classified failure behind [OfferKycGatePhase.error].
  final AppFailure? failure;

  final KycStatus status;

  bool get isApproved => status == KycStatus.approved;
  bool get isPending => status == KycStatus.pending;
  bool get isRejected => status == KycStatus.rejected;

  OfferKycGateState copyWith({
    OfferKycGatePhase? phase,
    KycStatus? status,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return OfferKycGateState(
      phase: phase ?? this.phase,
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [phase, status, failure];
}
