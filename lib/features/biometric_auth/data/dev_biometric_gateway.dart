import '../domain/biometric_gateway.dart';

/// This gateway makes [authenticate] resolve to `true` so that, in DEBUG builds
/// DEBUG-ONLY: this type is wired in `injection_container.dart` exclusively
class DevBiometricGateway implements BiometricGateway {
  const DevBiometricGateway();

  @override
  Future<bool> isAvailable() async => false;

  /// DEBUG override: the challenge always succeeds so the lock screen unlocks
  @override
  Future<bool> authenticate({required String reason}) async => true;
}
