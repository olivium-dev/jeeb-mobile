class RegistrationAttemptPolicy {
  const RegistrationAttemptPolicy({
    this.maxAttempts = 3,
    this.resendCooldown = const Duration(seconds: 60),
    this.lockoutDuration = const Duration(seconds: 60),
  });

  final int maxAttempts;

  final Duration resendCooldown;

  final Duration lockoutDuration;
}
