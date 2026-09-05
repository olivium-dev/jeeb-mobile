import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../kyc/domain/kyc_gateway.dart';
import 'offer_kyc_gate_state.dart';

class OfferKycGateCubit extends Cubit<OfferKycGateState> {
  OfferKycGateCubit({required KycGateway gateway})
      : _gateway = gateway,
        super(const OfferKycGateState()) {
    loadStatus();
  }

  final KycGateway _gateway;

  bool _inFlight = false;

  Future<void> loadStatus() async {
    if (_inFlight) return;
    _inFlight = true;
    emit(state.copyWith(
      phase: OfferKycGatePhase.loading,
      clearFailure: true,
    ));
    try {
      final submission = await _gateway.fetchStatus();
      emit(state.copyWith(
        phase: OfferKycGatePhase.ready,
        status: submission.status,
      ));
    } catch (e) {
      emit(state.copyWith(
        phase: OfferKycGatePhase.error,
        failure: e is KycGatewayException ? e.failure : AppFailure.of(e),
      ));
    } finally {
      _inFlight = false;
    }
  }
}
