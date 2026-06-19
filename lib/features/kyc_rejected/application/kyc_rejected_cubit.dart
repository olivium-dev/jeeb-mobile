import 'package:flutter_bloc/flutter_bloc.dart';

import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import 'kyc_rejected_state.dart';

/// Loads the FINAL KYC rejection detail for the kyc-rejected screen (JM-043).
///
/// Reuses the existing KYC domain side-channel ([KycGateway.fetchStatus] →
/// `GET /v1/kyc/status`, the app-rewrite of `GET /user-management/users/:userId
/// /kyc`). The decision itself is FINAL (D52/D87): this cubit NEVER offers a
/// resubmit path — it only fetches the structured `rejection_reason` so the
/// body can name the cause. Any non-rejected/absent/failed response degrades to
/// the generic FINAL copy rather than erroring out, because the route is only
/// reached on a rejected decision (JM-042 edge + `jeeb.seam.kyc_status=rejected`).
class KycRejectedCubit extends Cubit<KycRejectedState> {
  KycRejectedCubit(this._gateway) : super(const KycRejectedState());

  final KycGateway _gateway;

  Future<void> load() async {
    emit(state.copyWith(status: KycRejectedStatus.loading));
    try {
      final submission = await _gateway.fetchStatus();
      emit(state.copyWith(
        status: KycRejectedStatus.loaded,
        rejectionReason: submission.status == KycStatus.rejected
            ? submission.rejectionReason
            : null,
        clearRejectionReason: submission.status != KycStatus.rejected,
        submittedAt: submission.submittedAt,
      ));
    } catch (_) {
      emit(state.copyWith(status: KycRejectedStatus.error));
    }
  }
}
