import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/change_password_policy.dart';
import 'password_security_state.dart';

class PasswordSecurityCubit extends Cubit<PasswordSecurityState> {
  PasswordSecurityCubit({
    ChangePasswordPolicy policy = const ChangePasswordPolicy(),
  })  : _policy = policy,
        super(const PasswordSecurityState());

  final ChangePasswordPolicy _policy;

  bool _inFlight = false;

  void toggleCurrentObscured() =>
      emit(state.copyWith(currentObscured: !state.currentObscured));

  void toggleNewObscured() =>
      emit(state.copyWith(newObscured: !state.newObscured));

  void toggleConfirmObscured() =>
      emit(state.copyWith(confirmObscured: !state.confirmObscured));

  void acknowledgeError() {
    if (state.status == PasswordSecurityStatus.failed) {
      emit(state.copyWith(
        status: PasswordSecurityStatus.idle,
        clearValidation: true,
      ));
    }
  }

  void submit({
    required String current,
    required String newPassword,
    required String confirm,
  }) {
    if (state.status == PasswordSecurityStatus.submitting || _inFlight) return;
    _inFlight = true;

    final validation = _policy.validate(
      current: current,
      newPassword: newPassword,
      confirm: confirm,
    );
    if (validation != ChangePasswordValidation.valid) {
      emit(state.copyWith(
        status: PasswordSecurityStatus.failed,
        validation: validation,
      ));
      _inFlight = false;
      return;
    }

    emit(state.copyWith(
      status: PasswordSecurityStatus.unavailable,
      unavailableNonce: state.unavailableNonce + 1,
      clearValidation: true,
    ));
    _inFlight = false;
  }
}
