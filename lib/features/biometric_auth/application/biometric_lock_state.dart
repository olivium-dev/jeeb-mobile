import '../domain/biometric_gateway.dart';

/// (40_GUARDRAILS_ARCH §5.5). It MUST default to [BiometricLockPhase.disabled]
/// 40_GUARDRAILS_ARCH §2/§3, scoped to the single authenticate action): it
enum BiometricLockPhase {
  unknown,

  locked,

  unlocked,

  disabled,
}

enum BiometricPromptStatus {
  idle,

  prompting,

  failed,
}

class BiometricLockState {
  const BiometricLockState({
    this.phase = BiometricLockPhase.disabled,
    this.prompt = BiometricPromptStatus.idle,
    this.failure,
  });

  final BiometricLockPhase phase;

  final BiometricPromptStatus prompt;

  /// Why the OS refused, when it did. Null for a plain declined attempt.
  final BiometricFailure? failure;

  bool get isPrompting => prompt == BiometricPromptStatus.prompting;

  bool get hasFailed => prompt == BiometricPromptStatus.failed;

  bool get isUnlocked => phase == BiometricLockPhase.unlocked;

  /// True when the OS will never accept another attempt, so the screen must
  /// stop offering a Retry and promote the password fallback (R6).
  bool get isTerminalFailure =>
      failure == BiometricFailure.lockedOut ||
      failure == BiometricFailure.notEnrolled ||
      failure == BiometricFailure.unavailable ||
      failure == BiometricFailure.noDeviceCredential;

  BiometricLockState copyWith({
    BiometricLockPhase? phase,
    BiometricPromptStatus? prompt,
    BiometricFailure? failure,
    bool clearFailure = false,
  }) =>
      BiometricLockState(
        phase: phase ?? this.phase,
        prompt: prompt ?? this.prompt,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}
