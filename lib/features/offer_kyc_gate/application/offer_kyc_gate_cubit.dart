import 'package:flutter_bloc/flutter_bloc.dart';

import '../../kyc/domain/kyc_gateway.dart';
import 'offer_kyc_gate_state.dart';

/// Reads the jeeber's live KYC decision for the offer KYC gate (JM-044) from the
/// REAL mock endpoint via [KycGateway.fetchStatus] (`GET /v1/kyc/status`,
/// rewritten to `/user-management/v1/kyc`; the JM-044 AC's
/// `GET /user-management/users/:userId/kyc`). The identity is resolved from the
/// `mock-jwt-access-<userId>` bearer the Dio client attaches (backender K1), so
/// no userId path-param is needed here.
///
/// This drives ONLY the optional status line on the gate — the gate's three
/// exits + the top-up note always render. A failed / pending fetch never blocks
/// the CTAs (the gate degrades to "no status line"), keeping the D38 invariant
/// independent of the network (the invariant itself is enforced upstream by the
/// JM-048 feed routing an unapproved jeeber here in the first place).
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
      // Degrade gracefully: keep the gate fully usable, just drop the status
      // line. The exits + top-up note do not depend on this read.
      emit(state.copyWith(phase: OfferKycGatePhase.error));
    }
  }
}
