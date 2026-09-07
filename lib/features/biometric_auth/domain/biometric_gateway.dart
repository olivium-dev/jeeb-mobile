abstract class BiometricGateway {
  Future<bool> isAvailable();

  /// `false` = declined/cancelled; a terminal OS refusal is thrown as a
  /// [BiometricAuthException] (widening the return type would break R3).
  Future<bool> authenticate({required String reason});
}

/// Why the OS refused, so the screen stops offering a Retry that cannot win.
enum BiometricFailure {
  /// Too many wrong attempts; the sensor is cooling down.
  lockedOut,

  /// The device supports biometrics but none are enrolled.
  notEnrolled,

  /// No usable sensor on this device / platform.
  unavailable,

  /// No passcode set, so there is no credential to fall back to.
  noDeviceCredential,

  unknown,
}

class BiometricAuthException implements Exception {
  const BiometricAuthException(this.failure);

  final BiometricFailure failure;

  @override
  String toString() => 'BiometricAuthException(${failure.name})';
}

class UnavailableBiometricGateway implements BiometricGateway {
  const UnavailableBiometricGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
