/// Policy constants for the phone+OTP registration flow.
///
/// Centralised so widget tests and the cubit reference the same numbers, and
/// so a future product change (e.g. raising lockout to 5 min) edits one place.
class RegistrationAttemptPolicy {
  const RegistrationAttemptPolicy({
    this.maxAttempts = 3,
    this.resendCooldown = const Duration(seconds: 60),
    this.lockoutDuration = const Duration(seconds: 60),
  });

  /// Number of consecutive wrong OTPs the user is allowed before the lockout
  /// screen kicks in. The third wrong code triggers lockout.
  final int maxAttempts;

  /// How long after a successful OTP send the user must wait before the
  /// resend button becomes tappable again.
  final Duration resendCooldown;

  /// How long the lockout banner counts down before the user is sent back to
  /// the phone step with a fresh attempt budget.
  final Duration lockoutDuration;
}
