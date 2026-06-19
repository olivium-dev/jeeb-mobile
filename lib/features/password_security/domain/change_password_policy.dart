// PURE Dart. No Flutter / Dio / GetIt imports (Clean Architecture,
// 40_GUARDRAILS_ARCH §1). Change-password validation for the password-security
// screen (JM-061).
//
// This intentionally mirrors `auth/domain/set_password_policy.dart` (the
// JM-022 set-password floor) so the change-password form and the set-password
// form share one strength definition, and adds the two extra rules a CHANGE
// (not a first-set) implies: a current-password field must be present, and the
// new password must differ from the current one.

/// The outcome of validating a change-password submission (current / new /
/// confirm).
///
/// JM-061 AC: "current/new/confirm fields + validation". The screen surfaces a
/// strength miss through the `password_strength_error` node and a mismatch
/// through the `password_mismatch_error` node (67_W34_TEST_PLAN §JM-061), so the
/// two reasons are kept distinct here.
enum ChangePasswordValidation {
  /// New + confirm match, new clears the strength floor, and differs from the
  /// current password.
  valid,

  /// One or more required fields are empty.
  empty,

  /// The new password is too weak (below the strength floor) →
  /// `password_strength_error`.
  weak,

  /// New and confirm differ → `password_mismatch_error`.
  mismatch,

  /// The new password equals the current one (no-op change) →
  /// `password_strength_error` (reuses the strength node; "choose a different
  /// password" copy).
  sameAsCurrent,
}

/// Pure change-password policy for the password-security screen (JM-061).
///
/// Strength floor (R-F, recorded inline; identical to [SetPasswordPolicy] in
/// the auth domain so the two surfaces never diverge): at least 8 characters
/// containing at least one letter and one digit. The mock has no dedicated
/// change-password endpoint — the new password is persisted through
/// `POST /v1/auth/set-password` (the in-app contract, 42_GUARDRAILS_MOCK W-1
/// FLOOR), which accepts any non-empty password — so this is a client-side UX
/// guard, not a server contract.
class ChangePasswordPolicy {
  const ChangePasswordPolicy();

  /// Minimum acceptable password length (R-F; matches SetPasswordPolicy).
  static const int minLength = 8;

  /// Returns whether [password] alone clears the strength floor.
  bool isStrong(String password) {
    if (password.length < minLength) return false;
    final hasLetter = password.contains(RegExp('[A-Za-z]'));
    final hasDigit = password.contains(RegExp('[0-9]'));
    return hasLetter && hasDigit;
  }

  /// Validates a change-password submission. Order matters — emptiness first
  /// (most actionable), then strength, then the new≠current rule, then the
  /// new==confirm mismatch — so the single most useful message wins.
  ChangePasswordValidation validate({
    required String current,
    required String newPassword,
    required String confirm,
  }) {
    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      return ChangePasswordValidation.empty;
    }
    if (!isStrong(newPassword)) {
      return ChangePasswordValidation.weak;
    }
    if (newPassword == current) {
      return ChangePasswordValidation.sameAsCurrent;
    }
    if (newPassword != confirm) {
      return ChangePasswordValidation.mismatch;
    }
    return ChangePasswordValidation.valid;
  }
}
