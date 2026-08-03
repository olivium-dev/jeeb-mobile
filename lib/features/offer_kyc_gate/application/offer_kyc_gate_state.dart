import 'package:equatable/equatable.dart';

import '../../kyc/domain/kyc_submission.dart';

enum OfferKycGatePhase { loading, ready, error }

class OfferKycGateState extends Equatable {
  const OfferKycGateState({
    this.phase = OfferKycGatePhase.loading,
    this.status = KycStatus.notSubmitted,
  });

  final OfferKycGatePhase phase;

  final KycStatus status;

  bool get isApproved => status == KycStatus.approved;
  bool get isPending => status == KycStatus.pending;
  bool get isRejected => status == KycStatus.rejected;

  OfferKycGateState copyWith({
    OfferKycGatePhase? phase,
    KycStatus? status,
  }) {
    return OfferKycGateState(
      phase: phase ?? this.phase,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [phase, status];
}
