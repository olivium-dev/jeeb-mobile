import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../../kyc/domain/kyc_submission.dart';

enum KycRejectedStatus { loading, loaded, error }

class KycRejectedState extends Equatable {
  const KycRejectedState({
    this.status = KycRejectedStatus.loading,
    this.failure,
    this.decision,
    this.rejectionReason,
    this.submittedAt,
  });

  final KycRejectedStatus status;

  /// The classified failure behind [KycRejectedStatus.error].
  final AppFailure? failure;

  /// Server-authoritative decision returned by `GET /v1/kyc/status`.
  /// Null while loading or when the read failed.
  final KycStatus? decision;

  final KycRejectionReason? rejectionReason;

  final DateTime? submittedAt;

  bool get isLoading => status == KycRejectedStatus.loading;
  bool get hasError => status == KycRejectedStatus.error;

  bool get isAuthoritativelyRejected =>
      status == KycRejectedStatus.loaded && decision == KycStatus.rejected;

  /// KYCR-01: only an AUTHORITATIVE non-rejected decision may redirect. A
  /// failed read used to silently bounce the user off the appeal screen.
  bool get shouldLeaveRejectedRoute =>
      status == KycRejectedStatus.loaded && decision != KycStatus.rejected;

  KycRejectedState copyWith({
    KycRejectedStatus? status,
    AppFailure? failure,
    bool clearFailure = false,
    KycStatus? decision,
    bool clearDecision = false,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? submittedAt,
  }) {
    return KycRejectedState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      decision: clearDecision ? null : (decision ?? this.decision),
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  List<Object?> get props =>
      [status, failure, decision, rejectionReason, submittedAt];
}
