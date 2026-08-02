import 'package:flutter_bloc/flutter_bloc.dart';

import 'role_eligibility.dart';

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
