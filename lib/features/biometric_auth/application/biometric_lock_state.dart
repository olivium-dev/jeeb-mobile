/// JM-005 (D23) — biometric-unlock state.
///
/// `phase` is the router-facing signal: `app_router.dart`'s biometric gate
/// keys off [BiometricLockPhase.locked] to hold a returning enrolled user on
/// `/lock`, and releases (`/lock` → `/`) the instant `phase != locked`
/// (40_GUARDRAILS_ARCH §5.5). It MUST default to [BiometricLockPhase.disabled]
/// so a cold start with no enrolment never short-circuits navigation to
/// `/lock` (preserves the contract `AppRouter.create` + `app.dart` rely on).
///
/// `prompt` is the screen-local sub-status (the 4-state UI machine of
/// 40_GUARDRAILS_ARCH §2/§3, scoped to the single authenticate action): it
/// drives the prompting spinner / failure copy without changing the routing
/// `phase`. Keeping the two orthogonal means a failed/declined biometric leaves
/// `phase == locked` (the gate still holds `/lock`) while the screen shows a
/// retry affordance — exactly the JM-005 AC3 shape (fall back to password).
enum BiometricLockPhase {
  /// Evaluation has not finished — the router gate is a NO-OP (no flash of
  /// `/lock` during the cold-start keystore/preference read).
  unknown,

  /// Returning enrolled user: the gate forces `/lock` and holds there.
  locked,

  /// Authenticated (or the user chose the password fallback): the gate releases
  /// `/lock`. On `/lock` the router redirects to `/` (last-used tab, D75); when
  /// the screen has already navigated to `/login` the gate simply allows it.
  unlocked,

  /// No biometric enrolment / unavailable: the gate never engages.
  disabled,
}

/// Screen-local status for the single `authenticate` action (JM-005 §2.6).
enum BiometricPromptStatus {
  /// Idle — prompt shown, awaiting the authenticate CTA.
  idle,

  /// Platform biometric dialog is in flight.
  prompting,

  /// The biometric check failed or was declined — show retry + fallback.
  failed,
}

class BiometricLockState {
  const BiometricLockState({
    this.phase = BiometricLockPhase.disabled,
    this.prompt = BiometricPromptStatus.idle,
  });

  /// Router-facing routing signal (see [BiometricLockPhase]).
  final BiometricLockPhase phase;

  /// Screen-local authenticate-action status (see [BiometricPromptStatus]).
  final BiometricPromptStatus prompt;

  /// True while the platform biometric dialog is in flight (disables the CTA).
  bool get isPrompting => prompt == BiometricPromptStatus.prompting;

  /// True after a failed/declined attempt — the screen surfaces a retry hint.
  bool get hasFailed => prompt == BiometricPromptStatus.failed;

  /// True once authentication (or the password-fallback bypass) has released
  /// the routing gate. On `/lock` this transition drives the central router
  /// redirect (`/lock` → `/`, the AC2 success path); the screen itself does not
  /// navigate on it.
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
