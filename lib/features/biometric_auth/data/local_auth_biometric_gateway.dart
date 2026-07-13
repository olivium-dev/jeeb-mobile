import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/biometric_gateway.dart';

/// Production [BiometricGateway] backed by the real `local_auth` plugin
/// (JEBV4-213 / E18, Q-077).
///
/// Replaces [UnavailableBiometricGateway] on the RELEASE code path (see
/// `injection_container.dart`). Debug builds keep the deterministic
/// [DevBiometricGateway] so the emulator/CI dev-seam harness is unchanged; this
/// class is therefore only reachable in release binaries.
///
/// It wraps [LocalAuthentication] behind the existing port so the `/lock`
/// screen and [BiometricLockCubit] never import the plugin directly:
///
///   * [isAvailable] reports whether a *biometric* is actually enrolled — the
///     device supports auth, the hardware can check biometrics, AND at least
///     one factor (Face ID / fingerprint) is enrolled. This mirrors the prior
///     gateway contract (`false` on an emulator with no enrolled biometric),
///     so `BiometricLockCubit.evaluate` keeps its
///     `canChallenge = available || hasPinFallback` shape.
///
///   * [authenticate] drives the OS dialog with `biometricOnly: false`, so when
///     no biometric is enrolled the platform offers the **device credential**
///     (PIN / pattern / password) as the fallback and still resolves the
///     challenge — the JEBV4-213 DoD "on an emulator without biometric the
///     PIN/password fallback unlocks". `stickyAuth: true` survives an
///     app-backgrounding mid-prompt. Any [PlatformException] (no hardware,
///     lockout, user cancel surfaced as an error) is mapped to `false` so the
///     lock screen shows retry + the app-level password fallback rather than
///     crashing (AC3).
///
/// Android additionally requires the host Activity to be a
/// `FlutterFragmentActivity` and the `USE_BIOMETRIC` permission — both wired in
/// `android/app/src/main/...` alongside this change.
class LocalAuthBiometricGateway implements BiometricGateway {
  LocalAuthBiometricGateway({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      if (!await _localAuth.canCheckBiometrics) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // biometricOnly: false → the OS offers the device credential
          // (PIN / pattern / password) as the fallback challenge when no
          // biometric is enrolled. This is the DoD fallback-unlock path.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      // No hardware, lockout, or a platform-surfaced cancel is a failed
      // attempt — never crash the lock screen; the user retries or falls back.
      return false;
    }
  }
}
