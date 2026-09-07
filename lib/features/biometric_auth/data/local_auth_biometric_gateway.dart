import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/biometric_gateway.dart';

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
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // UX-24: swallowing these made lockout/not-enrolled indistinguishable
      // from a wrong finger, so the screen kept offering a futile Retry.
      throw BiometricAuthException(_mapPlatformCode(e.code));
    }
  }

  static BiometricFailure _mapPlatformCode(String code) => switch (code) {
    'LockedOut' || 'PermanentlyLockedOut' => BiometricFailure.lockedOut,
    'NotEnrolled' => BiometricFailure.notEnrolled,
    'NotAvailable' || 'OtherOperatingSystem' => BiometricFailure.unavailable,
    'PasscodeNotSet' => BiometricFailure.noDeviceCredential,
    _ => BiometricFailure.unknown,
  };
}
