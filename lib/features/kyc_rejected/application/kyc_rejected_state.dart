import 'package:equatable/equatable.dart';

import '../../kyc/domain/kyc_submission.dart';

enum KycRejectedStatus { loading, loaded, error }

class KycRejectedState extends Equatable {
  const KycRejectedState({
    this.status = KycRejectedStatus.loading,
    this.rejectionReason,
    this.submittedAt,
  });

  final KycRejectedStatus status;

  final KycRejectionReason? rejectionReason;

  final DateTime? submittedAt;

  bool get isLoading => status == KycRejectedStatus.loading;
  bool get hasError => status == KycRejectedStatus.error;

  KycRejectedState copyWith({
    KycRejectedStatus? status,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? submittedAt,
  }) {
    return KycRejectedState(
      status: status ?? this.status,
      rejectionReason: clearRejectionReason
          ? null
          : (rejectionReason ?? this.rejectionReason),
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  List<Object?> get props => [status, rejectionReason, submittedAt];
}
