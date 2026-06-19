import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/change_password_policy.dart';
import 'password_security_state.dart';

/// Drives the change-password form on the password-security screen (JM-061).
/// Owns the three visibility toggles and the current/new/confirm validation
/// gate.
///
/// SCOPE (JM-061 AC `Mock: —`; integrator note "no mock dependency — this is
/// local validation"): the change path validates locally and reaches
/// [PasswordSecurityStatus.succeeded]; the screen's `listener` then routes back
/// to customer-profile. It does NOT hit the network — the only server write in
/// this surface is the SOCIAL-ONLY "set a password" path, which is delegated to
/// the existing JM-022 set-password screen (`/set-password?mode=in-app-social`)
/// via the `password_set_entry` CTA, and that screen owns the
/// `POST /v1/auth/set-password` call. The mock has no current-password verify
/// nor a change-by-bearer endpoint (42_GUARDRAILS_MOCK), so verifying the
/// current password server-side is out of contract; this cubit treats the
/// current field as a required, client-validated input only.
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
  /// On a valid form it emits [PasswordSecurityStatus.succeeded] (the screen
  /// pops back to customer-profile).
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

    // Local-validation success (AC `Mock: —`). Reach succeeded so the screen's
    // listener navigates back to the profile.
    emit(state.copyWith(
      status: PasswordSecurityStatus.succeeded,
      clearValidation: true,
    ));
  }
}
