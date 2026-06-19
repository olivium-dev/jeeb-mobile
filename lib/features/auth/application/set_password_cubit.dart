import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/set_password_policy.dart';
import 'set_password_state.dart';

/// Drives the set-password screen (JM-022). Owns the two visibility toggles,
/// the mismatch/strength validation gate, and the `POST /v1/auth/set-password`
/// submit. The success destination (recovery → `/login`; in-app-social →
/// customer-profile, D90) is the screen's `listener` concern — the cubit just
/// reaches [SetPasswordStatus.succeeded].
///
/// `email` + `resetToken` are handed in at construction (from the verify-code
/// step's `extra`, JM-021). In recovery mode the mock requires the `resetToken`;
/// in in-app-social mode it is optional (the user is already authenticated)
/// (42_GUARDRAILS_MOCK W-1 FLOOR set-password row).
class SetPasswordCubit extends Cubit<SetPasswordState> {
  SetPasswordCubit({
    required AuthRepository repository,
    required String email,
    String? resetToken,
    SetPasswordPolicy policy = const SetPasswordPolicy(),
  })  : _repository = repository,
        _email = email,
        _resetToken = resetToken,
        _policy = policy,
        super(const SetPasswordState());

  final AuthRepository _repository;
  final String _email;
  final String? _resetToken;
  final SetPasswordPolicy _policy;

  /// Flips masking on the new-password field (`setpw_new_visibility_toggle`).
  void toggleNewObscured() =>
      emit(state.copyWith(newObscured: !state.newObscured));

  /// Flips masking on the confirm-password field
  /// (`setpw_confirm_visibility_toggle`).
  void toggleConfirmObscured() =>
      emit(state.copyWith(confirmObscured: !state.confirmObscured));

  /// Clears a surfaced error once the user edits a field again, so the
  /// `setpw_validation_error` node does not linger after a correction.
  void acknowledgeError() {
    if (state.status == SetPasswordStatus.failed) {
      emit(state.copyWith(
        status: SetPasswordStatus.idle,
        clearValidation: true,
        clearFailure: true,
      ));
    }
  }

  /// Validates then submits. On a client-side validation miss (mismatch / weak /
  /// empty) it emits [SetPasswordStatus.failed] with the [validation] reason and
  /// does NOT call the network (AC3 — form not submitted, screen stays). On a
  /// 200 it persists tokens (via the repo) and emits
  /// [SetPasswordStatus.succeeded].
  Future<void> submit({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state.status == SetPasswordStatus.submitting) return;

    final validation = _policy.validate(
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (validation != SetPasswordValidation.valid) {
      emit(state.copyWith(
        status: SetPasswordStatus.failed,
        validation: validation,
        clearFailure: true,
      ));
      return;
    }

    emit(state.copyWith(
      status: SetPasswordStatus.submitting,
      clearValidation: true,
      clearFailure: true,
    ));
    try {
      final session = await _repository.setPassword(
        email: _email,
        password: newPassword,
        resetToken: _resetToken,
      );
      emit(state.copyWith(
        status: SetPasswordStatus.succeeded,
        session: session,
      ));
    } on AuthRepositoryException catch (e) {
      emit(state.copyWith(
        status: SetPasswordStatus.failed,
        failure: e.failure,
        clearValidation: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: SetPasswordStatus.failed,
        failure: AuthFailure.unknown,
        clearValidation: true,
      ));
    }
  }
}
