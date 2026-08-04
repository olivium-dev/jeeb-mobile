import 'package:flutter_bloc/flutter_bloc.dart';

import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import 'kyc_rejected_state.dart';

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
