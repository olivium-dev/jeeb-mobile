// PURE Dart. No Flutter / Dio / GetIt imports (Clean Architecture,
// 40_GUARDRAILS_ARCH §1). Shared password-strength + mismatch policy for the
// set-password screen (JM-022).

/// The outcome of validating a new password + its confirmation.
///
/// JM-022 AC: "Mismatch/strength validation enforced". The screen surfaces a
/// single `setpw_validation_error` node (60_W0_TEST_PLAN §2.11) whenever this
/// is anything other than [valid]; the precise reason discriminates copy if the
/// integrator later splits the message.
enum SetPasswordValidation {
  /// New + confirm match and the password meets the strength floor.
  valid,

  /// New and confirm differ.
  mismatch,

  /// The password is too weak (below the strength floor).
  weak,

  /// One or both fields are empty.
  empty,
}

/// Pure password policy for the set-password screen (JM-022). Kept in `domain/`
/// so the cubit, the widget tests, and any future server-aligned rule share one
/// definition (40_GUARDRAILS_ARCH §1 — domain is the contract).
///
/// Strength floor (R-F, blueprint-consistent / least-surprising, recorded
/// inline): at least 8 characters, containing at least one letter and at least
/// one digit. The mock `set-password` route accepts any non-empty password
/// (W-1 FLOOR), so this is a client-side UX guard, not a server contract — it
/// matches the Maestro fixtures (`NewPassword123!`, `SocialPass456!` pass;
/// the AC3 mismatch case is caught before the strength check).
class SetPasswordPolicy {
  const SetPasswordPolicy();

  /// Minimum acceptable password length (R-F).
  static const int minLength = 8;

  /// Returns whether [password] alone clears the strength floor.
  bool isStrong(String password) {
    if (password.length < minLength) return false;
    final hasLetter = password.contains(RegExp('[A-Za-z]'));
    final hasDigit = password.contains(RegExp('[0-9]'));
    return hasLetter && hasDigit;
  }

  /// Validates the new password against its confirmation. Order matters:
  /// emptiness first, then strength, then mismatch — so the most actionable
  /// message wins.
  SetPasswordValidation validate({
    required String newPassword,
    required String confirmPassword,
  }) {
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      return SetPasswordValidation.empty;
    }
    if (!isStrong(newPassword)) {
      return SetPasswordValidation.weak;
    }
    if (newPassword != confirmPassword) {
      return SetPasswordValidation.mismatch;
    }
    return SetPasswordValidation.valid;
  }
}
