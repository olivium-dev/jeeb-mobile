import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../domain/role_switch_repository.dart';

/// T-MOB-028: View-model state emitted by [RoleSwitchCubit].
class RoleSwitchState extends Equatable {
  const RoleSwitchState({
    this.activeRole = 'client',
    this.isInFlight = false,
    this.kycGated = false,
    this.hasError = false,
  });

  /// Currently active role identifier ('client' or 'jeeber').
  final String activeRole;

  /// True while a POST /v1/users/me/role/switch call is in flight.
  final bool isInFlight;

  /// True when the gateway returned 403 (KYC gate). The widget uses this
  /// to show the KYC-required dialog (AC2).
  final bool kycGated;

  /// True when the network call failed. Cleared by [RoleSwitchCubit.clearError].
  final bool hasError;

  RoleSwitchState copyWith({
    String? activeRole,
    bool? isInFlight,
    bool? kycGated,
    bool? hasError,
  }) {
    return RoleSwitchState(
      activeRole: activeRole ?? this.activeRole,
      isInFlight: isInFlight ?? this.isInFlight,
      kycGated: kycGated ?? this.kycGated,
      hasError: hasError ?? this.hasError,
    );
  }

  @override
  List<Object?> get props => [activeRole, isInFlight, kycGated, hasError];
}

/// T-MOB-028: Drives the Settings → Active Role toggle.
///
/// On [switchTo]:
///   1. Fires POST /v1/users/me/role/switch.
///   2. On 200: updates [activeRole] and the [RoleCubit] (provided by caller).
///   3. On 403: sets [kycGated] so the widget can show the KYC dialog (AC2).
///   4. On network error: sets [hasError] for an error snackbar.
class RoleSwitchCubit extends Cubit<RoleSwitchState> {
  RoleSwitchCubit({
    required RoleSwitchRepository repository,
    String initialRole = 'client',
  })  : _repository = repository,
        super(RoleSwitchState(activeRole: initialRole));

  final RoleSwitchRepository _repository;

  /// Switch the active role to [role] ('client' or 'jeeber'). No-ops if a
  /// call is already in flight or [role] equals the current active role.
  Future<void> switchTo(String role) async {
    if (state.isInFlight || role == state.activeRole) return;
    emit(state.copyWith(
      isInFlight: true,
      kycGated: false,
      hasError: false,
    ));
    try {
      final result = await _repository.switchRole(role);
      if (result == RoleSwitchResult.kycGated) {
        emit(state.copyWith(isInFlight: false, kycGated: true));
        return;
      }
      emit(state.copyWith(isInFlight: false, activeRole: role));
    } on RoleSwitchException {
      emit(state.copyWith(isInFlight: false, hasError: true));
    }
  }

  /// Call after consuming [RoleSwitchState.kycGated] so the dialog is
  /// not shown again on the next rebuild.
  void clearKycGate() {
    if (!state.kycGated) return;
    emit(state.copyWith(kycGated: false));
  }

  /// Call after showing the error snackbar.
  void clearError() {
    if (!state.hasError) return;
    emit(state.copyWith(hasError: false));
  }
}
