import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import 'kyc_rejected_state.dart';

class KycRejectedCubit extends Cubit<KycRejectedState> {
  KycRejectedCubit(this._gateway) : super(const KycRejectedState());

  final KycGateway _gateway;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: KycRejectedStatus.loading,
        clearDecision: true,
        clearRejectionReason: true,
        clearFailure: true,
      ),
    );
    try {
      final submission = await _gateway.fetchStatus();
      emit(
        state.copyWith(
          status: KycRejectedStatus.loaded,
          decision: submission.status,
          rejectionReason: submission.status == KycStatus.rejected
              ? submission.rejectionReason
              : null,
          clearRejectionReason: submission.status != KycStatus.rejected,
          submittedAt: submission.submittedAt,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: KycRejectedStatus.error,
          failure: e is KycGatewayException ? e.failure : AppFailure.of(e),
          clearDecision: true,
          clearRejectionReason: true,
        ),
      );
    }
  }
}
