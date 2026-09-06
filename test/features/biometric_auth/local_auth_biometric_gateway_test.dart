import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/local_auth_biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages, LocalAuthPlatform;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A scripted fake for the `local_auth` platform channel (JEBV4-213 / E18).
/// The ticket asks for widget tests with a "fake auth channel"; the robust,
/// version-stable seam is [LocalAuthPlatform.instance] (what
class _FakeLocalAuthPlatform extends LocalAuthPlatform
    with MockPlatformInterfaceMixin {
  bool deviceSupported = true;
  bool canCheck = true;
  List<BiometricType> enrolled = const [BiometricType.fingerprint];
  bool authResult = true;
  bool throwOnSupported = false;
  bool throwOnAuthenticate = false;
  String authenticateErrorCode = 'LockedOut';

  // Recorded from the last authenticate() call.
  AuthenticationOptions? lastOptions;
  String? lastReason;

  @override
  Future<bool> isDeviceSupported() async {
    if (throwOnSupported) {
      throw PlatformException(code: 'no_hardware');
    }
    return deviceSupported;
  }

  @override
  Future<bool> deviceSupportsBiometrics() async => canCheck;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => enrolled;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    lastReason = localizedReason;
    lastOptions = options;
    if (throwOnAuthenticate) {
      throw PlatformException(code: authenticateErrorCode);
    }
    return authResult;
  }

  @override
  Future<bool> stopAuthentication() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeLocalAuthPlatform fake;
  late LocalAuthBiometricGateway gateway;

  setUp(() {
    fake = _FakeLocalAuthPlatform();
    LocalAuthPlatform.instance = fake;
    gateway = LocalAuthBiometricGateway(localAuth: LocalAuthentication());
  });

  group('isAvailable', () {
    test('true when supported, can-check, and a biometric is enrolled', () async {
      fake
        ..deviceSupported = true
        ..canCheck = true
        ..enrolled = const [BiometricType.face];
      expect(await gateway.isAvailable(), isTrue);
    });

    test('false when the device does not support auth', () async {
      fake.deviceSupported = false;
      expect(await gateway.isAvailable(), isFalse);
    });

    test('false when hardware cannot check biometrics', () async {
      fake
        ..deviceSupported = true
        ..canCheck = false;
      expect(await gateway.isAvailable(), isFalse);
    });

    test('false on an emulator with no enrolled biometric', () async {
      // The DoD emulator shape: supported + can-check, but nothing enrolled.
      fake
        ..deviceSupported = true
        ..canCheck = true
        ..enrolled = const [];
      expect(await gateway.isAvailable(), isFalse);
    });

    test('false (never throws) when the platform raises', () async {
      fake.throwOnSupported = true;
      expect(await gateway.isAvailable(), isFalse);
    });
  });

  group('authenticate', () {
    test('true when the OS challenge succeeds', () async {
      fake.authResult = true;
      expect(await gateway.authenticate(reason: 'Unlock Jeeb'), isTrue);
    });

    test('enables the device-credential (PIN/password) fallback', () async {
      // biometricOnly: false is what lets an emulator with no biometric fall
      await gateway.authenticate(reason: 'Unlock Jeeb');
      expect(fake.lastOptions, isNotNull);
      expect(fake.lastOptions!.biometricOnly, isFalse);
      expect(fake.lastOptions!.stickyAuth, isTrue);
    });

    test('forwards the caller reason to the OS dialog', () async {
      await gateway.authenticate(reason: "Confirm it's you to open Jeeb");
      expect(fake.lastReason, "Confirm it's you to open Jeeb");
    });

    test('false when the user declines / the challenge fails', () async {
      fake.authResult = false;
      expect(await gateway.authenticate(reason: 'Unlock Jeeb'), isFalse);
    });

    // UX-24: swallowing the PlatformException made lockout/not-enrolled
    // indistinguishable from a wrong finger, so the screen kept offering a
    // Retry the OS would refuse. The typed throw is the fix (R3: no signature
    // widened — a declined attempt still returns `false`).
    test('throws BiometricAuthException(lockedOut) on LockedOut', () async {
      fake
        ..throwOnAuthenticate = true
        ..authenticateErrorCode = 'LockedOut';
      await expectLater(
        gateway.authenticate(reason: 'Unlock Jeeb'),
        throwsA(isA<BiometricAuthException>().having(
          (e) => e.failure,
          'failure',
          BiometricFailure.lockedOut,
        )),
      );
    });

    test('maps PermanentlyLockedOut to lockedOut too', () async {
      fake
        ..throwOnAuthenticate = true
        ..authenticateErrorCode = 'PermanentlyLockedOut';
      await expectLater(
        gateway.authenticate(reason: 'Unlock Jeeb'),
        throwsA(isA<BiometricAuthException>().having(
          (e) => e.failure,
          'failure',
          BiometricFailure.lockedOut,
        )),
      );
    });

    test('maps NotEnrolled / NotAvailable / PasscodeNotSet by code', () async {
      fake.throwOnAuthenticate = true;
      const Map<String, BiometricFailure> cases = <String, BiometricFailure>{
        'NotEnrolled': BiometricFailure.notEnrolled,
        'NotAvailable': BiometricFailure.unavailable,
        'OtherOperatingSystem': BiometricFailure.unavailable,
        'PasscodeNotSet': BiometricFailure.noDeviceCredential,
        'something_else': BiometricFailure.unknown,
      };
      for (final MapEntry<String, BiometricFailure> row in cases.entries) {
        fake.authenticateErrorCode = row.key;
        await expectLater(
          gateway.authenticate(reason: 'Unlock Jeeb'),
          throwsA(isA<BiometricAuthException>().having(
            (e) => e.failure,
            'failure',
            row.value,
          )),
          reason: row.key,
        );
      }
    });
  });
}
