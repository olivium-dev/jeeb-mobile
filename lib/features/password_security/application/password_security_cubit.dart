import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/change_password_policy.dart';
import 'password_security_state.dart';

/// Drives the change-password form on the password-security screen (JM-061).
/// Owns the three visibility toggles and the current/new/confirm validation
/// gate.
///
/// SCOPE (B-33): the change-password form validates locally, but there is NO
/// change-password endpoint in the app's data layer — the gateway exposes only
/// `POST /v1/auth/set-password` (the SOCIAL-ONLY "set a password" leg, delegated
/// to the JM-022 set-password screen via the `password_set_entry` CTA); there is
/// no current-password verify nor a change-by-bearer contract
/// (42_GUARDRAILS_MOCK). This cubit therefore must NOT emit a fake success on a
/// valid form (the pre-B-33 behavior emitted `succeeded` + popped to profile
/// with ZERO network write, so the user believed the password changed). Instead
/// it reaches [PasswordSecurityStatus.unavailable]; the screen surfaces an
/// honest "not available yet" notice and stays put. When the gateway ships a
/// change-password endpoint, wire it in place of the `unavailable` emit.
class PasswordSecurityCubit extends Cubit<PasswordSecurityState> {
  PasswordSecurityCubit({
    ChangePasswordPolicy policy = const ChangePasswordPolicy(),
  })  : _policy = policy,
        super(const PasswordSecurityState());

  final ChangePasswordPolicy _policy;

  /// Flips masking on the current-password field
  /// (`password_current_field` — no dedicated toggle id is asserted, so this is
  /// wired through the field's own affordance only if added later).
  void toggleCurrentObscured() =>
      emit(state.copyWith(currentObscured: !state.currentObscured));

  /// Flips masking on the new-password field
  /// (`password_new_visibility_toggle`).
  void toggleNewObscured() =>
      emit(state.copyWith(newObscured: !state.newObscured));

  /// Flips masking on the confirm-password field
  /// (`password_confirm_visibility_toggle`).
  void toggleConfirmObscured() =>
      emit(state.copyWith(confirmObscured: !state.confirmObscured));

  /// Clears a surfaced error once the user edits a field again, so an error
  /// node does not linger after a correction.
  void acknowledgeError() {
    if (state.status == PasswordSecurityStatus.failed) {
      emit(state.copyWith(
        status: PasswordSecurityStatus.idle,
        clearValidation: true,
      ));
    }
  }

  /// Validates then "submits" the change. On a client-side validation miss it
  /// emits [PasswordSecurityStatus.failed] with the [ChangePasswordValidation]
  /// reason and does NOT navigate (validation stays on screen — 67_W34_TEST_PLAN
  /// nav assertion `password_submit_cta (mismatched) → password_mismatch_error`).
  /// On a valid form it emits [PasswordSecurityStatus.unavailable] (B-33: no
  /// change-password endpoint exists, so the screen shows an honest notice and
  /// does NOT navigate — it never fakes success).
  void submit({
    required String current,
    required String newPassword,
    required String confirm,
  }) {
    if (state.status == PasswordSecurityStatus.submitting) return;

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
      return;
    }

    // B-33: the form is valid, but the client has no change-password endpoint
    // to call. Do NOT fake success — reach the honest `unavailable` terminal
    // state so the screen surfaces a "not available yet" notice and stays put.
    emit(state.copyWith(
      status: PasswordSecurityStatus.unavailable,
      clearValidation: true,
    ));
  }
}
