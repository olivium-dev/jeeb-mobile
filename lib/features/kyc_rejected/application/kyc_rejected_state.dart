import 'package:equatable/equatable.dart';

import '../../kyc/domain/kyc_submission.dart';

enum KycRejectedStatus { loading, loaded, error }

class KycRejectedState extends Equatable {
  const KycRejectedState({
    this.status = KycRejectedStatus.loading,
    this.decision,
    this.rejectionReason,
    this.submittedAt,
  });

  final KycRejectedStatus status;

  /// Server-authoritative decision returned by `GET /v1/kyc/status`.
  /// Null while loading or when the read failed.
  final KycStatus? decision;

  final KycRejectionReason? rejectionReason;

  final DateTime? submittedAt;

  bool get isLoading => status == KycRejectedStatus.loading;
  bool get hasError => status == KycRejectedStatus.error;

  bool get isAuthoritativelyRejected =>
      status == KycRejectedStatus.loaded && decision == KycStatus.rejected;

  bool get shouldLeaveRejectedRoute =>
      hasError ||
      (status == KycRejectedStatus.loaded && decision != KycStatus.rejected);

  KycRejectedState copyWith({
    KycRejectedStatus? status,
    KycStatus? decision,
    bool clearDecision = false,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? submittedAt,
  }) {
    return KycRejectedState(
      status: status ?? this.status,
      decision: clearDecision ? null : (decision ?? this.decision),
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  List<Object?> get props => [status, decision, rejectionReason, submittedAt];
}
