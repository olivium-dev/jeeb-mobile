import 'package:equatable/equatable.dart';

import '../../kyc/domain/kyc_submission.dart';

/// Load phase for the kyc-rejected screen's status fetch.
enum KycRejectedStatus { loading, loaded, error }

/// State for [KycRejectedCubit].
///
/// The screen always renders the FINAL-rejection copy + the appeal/back CTAs
/// regardless of phase (the route is only ever reached when the back-office
/// decision is rejected — JM-042's `kyc_status_view_rejection` edge + the
/// `jeeb.seam.kyc_status=rejected` seam). The fetched [rejectionReason] only
/// enriches the body with the structured cause; a failed/absent fetch falls
/// back to the generic copy so the screen is never blank.
class KycRejectedState extends Equatable {
  const KycRejectedState({
    this.status = KycRejectedStatus.loading,
    this.rejectionReason,
    this.submittedAt,
  });

  final KycRejectedStatus status;

  /// Structured cause echoed by `GET /v1/kyc/status` (`rejection_reason`).
  /// Null until loaded, or when the back-office returned no structured reason.
  final KycRejectionReason? rejectionReason;

  /// Server-assigned submission timestamp, when present.
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
