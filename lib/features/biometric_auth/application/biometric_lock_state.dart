/// Stub created by sanity-build pass (2026-05-17).
///
/// app_router.dart depends on `BiometricLockState.phase` (typed
/// [BiometricLockPhase]). Defaulting `phase` to [BiometricLockPhase.disabled]
/// means the router never short-circuits to `/lock` during cold start.
enum BiometricLockPhase {
  unknown,
  locked,
  unlocked,
  disabled,
}

class BiometricLockState {
  const BiometricLockState({this.phase = BiometricLockPhase.disabled});

  final BiometricLockPhase phase;

  BiometricLockState copyWith({BiometricLockPhase? phase}) =>
      BiometricLockState(phase: phase ?? this.phase);
}
