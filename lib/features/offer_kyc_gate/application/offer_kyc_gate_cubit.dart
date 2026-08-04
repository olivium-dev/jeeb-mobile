import 'package:flutter_bloc/flutter_bloc.dart';

import '../../kyc/domain/kyc_gateway.dart';
import 'offer_kyc_gate_state.dart';

class OfferKycGateCubit extends Cubit<OfferKycGateState> {
  OfferKycGateCubit({required KycGateway gateway})
      : _gateway = gateway,
        super(const OfferKycGateState()) {
    loadStatus();
  }

  final KycGateway _gateway;

  Future<void> loadStatus() async {
    emit(state.copyWith(phase: OfferKycGatePhase.loading));
    try {
      final submission = await _gateway.fetchStatus();
      emit(state.copyWith(
        phase: OfferKycGatePhase.ready,
        status: submission.status,
      ));
    } catch (_) {
      emit(state.copyWith(phase: OfferKycGatePhase.error));
    }
  }
}
