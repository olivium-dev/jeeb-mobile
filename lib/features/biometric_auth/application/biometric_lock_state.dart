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
  });

  final BiometricLockPhase phase;

  final BiometricPromptStatus prompt;

  bool get isPrompting => prompt == BiometricPromptStatus.prompting;

  bool get hasFailed => prompt == BiometricPromptStatus.failed;

  bool get isUnlocked => phase == BiometricLockPhase.unlocked;

  BiometricLockState copyWith({
    BiometricLockPhase? phase,
    BiometricPromptStatus? prompt,
  }) =>
      BiometricLockState(
        phase: phase ?? this.phase,
        prompt: prompt ?? this.prompt,
      );
}
