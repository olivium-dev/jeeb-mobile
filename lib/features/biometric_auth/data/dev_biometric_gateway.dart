import '../domain/biometric_gateway.dart';

/// Debug-only [BiometricGateway] (RC-3, JM-005).
///
/// The emulator/CI device has no enrolled biometric, so the production
/// [UnavailableBiometricGateway] always returns `false` from [authenticate] —
/// which means the `/lock` screen can never release and the biometric-unlock
/// demo (JM-005) can never reach the shell.
///
/// This gateway makes [authenticate] resolve to `true` so that, in DEBUG builds
/// only, tapping `biometric_unlock_authenticate_cta` succeeds and the
/// [BiometricLockCubit] transitions `locked → unlocked`, releasing the router
/// gate to the shell (`shell_tab_requests`).
///
/// [isAvailable] stays `false` (matching production behaviour on a device with
/// no enrolled biometric). The lock still HOLDS on first entry because the seam
/// seeds a local PIN, so `canChallenge = true` via `hasPinFallback` — i.e. this
/// gateway only changes the OUTCOME of the challenge, not whether the lock is
/// shown.
///
/// DEBUG-ONLY: this type is wired in `injection_container.dart` exclusively
/// under `kDebugMode`. Release builds keep the production
/// [UnavailableBiometricGateway] and are entirely unchanged. It is never
/// referenced from a release code path, so it is tree-shaken out of release
/// binaries.
class DevBiometricGateway implements BiometricGateway {
  const DevBiometricGateway();

  /// Mirrors production: no biometric is "available" on the emulator. The lock
  /// is still held via the seam-seeded PIN fallback (`hasPin → canChallenge`).
  @override
  Future<bool> isAvailable() async => false;

  /// DEBUG override: the challenge always succeeds so the lock screen unlocks
  /// and routes to the shell. Release uses [UnavailableBiometricGateway] (false).
  @override
  Future<bool> authenticate({required String reason}) async => true;
}
