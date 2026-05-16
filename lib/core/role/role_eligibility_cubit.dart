import 'package:flutter_bloc/flutter_bloc.dart';

import 'role_eligibility.dart';

/// Publishes the inputs the [RoleToggle] uses to decide whether a role switch
/// is allowed (KYC approval + active-delivery flag).
///
/// Defaults are intentionally conservative: KYC is treated as not-yet-approved
/// and there is no active delivery. Other features (KYC status feed, active
/// delivery tracker) push updates in via [setKycApproved] / [setActiveDelivery]
/// once they have authoritative state.
class RoleEligibilityCubit extends Cubit<RoleEligibility> {
  RoleEligibilityCubit({RoleEligibility initial = const RoleEligibility()})
      : super(initial);

  void setKycApproved(bool approved) {
    if (state.isJeeberKycApproved == approved) return;
    emit(state.copyWith(isJeeberKycApproved: approved));
  }

  void setActiveDelivery(bool hasActiveDelivery) {
    if (state.hasActiveDelivery == hasActiveDelivery) return;
    emit(state.copyWith(hasActiveDelivery: hasActiveDelivery));
  }
}
