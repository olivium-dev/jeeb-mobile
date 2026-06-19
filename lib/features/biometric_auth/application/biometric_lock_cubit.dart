import 'package:flutter_bloc/flutter_bloc.dart';

import '../../settings/data/repositories/biometric_preference_repository_impl.dart';
import '../data/shared_prefs_pin_repository.dart';
import '../domain/biometric_gateway.dart';
import 'biometric_lock_state.dart';

/// JM-005 (D23) — the real biometric-unlock cubit.
///
/// Replaces the W0-INT sanity stub. Owns two responsibilities:
///
///   1. **Routing phase** ([BiometricLockState.phase]) — read by the
///      `app_router.dart` biometric gate (40_GUARDRAILS_ARCH §5.5). [evaluate]
///      decides, on cold start, whether a returning enrolled user is held on
///      `/lock` ([BiometricLockPhase.locked]) or passes straight through
///      ([BiometricLockPhase.disabled] when there is no enrolment). It starts
///      in [BiometricLockPhase.disabled] so the gate is inert until [evaluate]
///      runs, and never flashes `/lock` mid keystore/preference read.
///
///   2. **The authenticate action** — [authenticate] drives the platform
///      biometric dialog via the injected [BiometricGateway] (D23: NO OTP on a
///      biometric unlock — the gateway is the only challenge). On success the
///      `phase` flips to [BiometricLockPhase.unlocked], which releases the
///      router gate (`/lock` → `/`, last-used tab, D75). On
///      failure/decline the `phase` stays `locked` and the screen surfaces a
///      retry + the password fallback (AC3).
///
/// Lifted from `lib/features/biometric_login/` (the throwaway
/// `BiometricCubit`) into the canonical `biometric_auth` feature; the old
/// prompt screen/cubit are superseded by this + [BiometricLockScreen].
class BiometricLockCubit extends Cubit<BiometricLockState> {
  BiometricLockCubit({
    required BiometricPreferenceRepositoryImpl preference,
    required BiometricGateway gateway,
    required SharedPrefsPinRepository pinRepository,
  })  : _preference = preference,
        _gateway = gateway,
        _pinRepository = pinRepository,
        super(const BiometricLockState());

  final BiometricPreferenceRepositoryImpl _preference;
  final BiometricGateway _gateway;
  final SharedPrefsPinRepository _pinRepository;

  /// Reason string handed to the OS biometric dialog. Localized copy lives on
  /// the screen; the gateway reason is a platform-level fallback label.
  static const String _osPromptReason = "Confirm it's you to open Jeeb";

  /// Cold-start evaluation (JM-006 splash → biometric branch, JM-005 AC1).
  ///
  /// A returning user is "enrolled" when the user opted in
  /// (`preference.isEnabled()`) AND the device can actually satisfy the
  /// challenge — either the platform biometric is available
  /// (`gateway.isAvailable()`) or a local PIN fallback exists
  /// (`pinRepository.hasPin()`). Enrolled → hold on `/lock`
  /// ([BiometricLockPhase.locked]); otherwise the gate is disabled and the
  /// user routes normally.
  ///
  /// Re-entrant: only meaningful from the `unknown`/`disabled` cold state; once
  /// the user has unlocked we never re-lock within the same app session.
  Future<void> evaluate() async {
    if (state.phase == BiometricLockPhase.unlocked) return;
    final enabled = await _preference.isEnabled();
    if (!enabled) {
      _emit(state.copyWith(phase: BiometricLockPhase.disabled));
      return;
    }
    final available = await _gateway.isAvailable();
    final hasPinFallback = await _pinRepository.hasPin();
    final canChallenge = available || hasPinFallback;
    _emit(
      state.copyWith(
        phase: canChallenge
            ? BiometricLockPhase.locked
            : BiometricLockPhase.disabled,
      ),
    );
  }

  /// JM-005 AC2 — drive the platform biometric dialog. On success the routing
  /// gate releases (phase → unlocked) and the router lands the user on `/`
  /// (last-used tab). On failure/decline we stay locked and flag the prompt as
  /// failed so the screen shows retry + the password fallback. No OTP (D23).
  Future<void> authenticate() async {
    if (state.isPrompting) return;
    _emit(state.copyWith(prompt: BiometricPromptStatus.prompting));
    bool ok;
    try {
      ok = await _gateway.authenticate(reason: _osPromptReason);
    } catch (_) {
      // A gateway/platform exception is treated as a failed attempt — never
      // crash the lock screen; the user can retry or fall back to password.
      ok = false;
    }
    if (ok) {
      _emit(
        state.copyWith(
          phase: BiometricLockPhase.unlocked,
          prompt: BiometricPromptStatus.idle,
        ),
      );
    } else {
      _emit(state.copyWith(prompt: BiometricPromptStatus.failed));
    }
  }

  /// JM-005 AC3 — the user chose "use password instead". Releasing the routing
  /// gate (phase → unlocked) is required BEFORE the screen navigates to
  /// `/login`: while `phase == locked` the router gate would bounce any
  /// off-`/lock` location straight back to `/lock`. The screen emits this, then
  /// `goNamed('login')`; the synchronous redirect for `/login` sees a non-locked
  /// phase and a non-`/lock` location, so login sticks (no bounce-to-`/`).
  void usePasswordFallback() {
    _emit(
      state.copyWith(
        phase: BiometricLockPhase.unlocked,
        prompt: BiometricPromptStatus.idle,
      ),
    );
  }

  void _emit(BiometricLockState next) {
    if (!isClosed) emit(next);
  }
}
