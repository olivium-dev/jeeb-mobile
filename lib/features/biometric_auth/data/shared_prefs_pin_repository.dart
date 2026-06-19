import 'package:shared_preferences/shared_preferences.dart';

/// Local PIN fallback for biometric unlock (the password-less local challenge
/// used when the platform biometric is unavailable, see [BiometricLockCubit]).
///
/// Originally a sanity-build stub that hard-returned `false`; it now persists a
/// PIN in [SharedPreferences] so [BiometricLockCubit.evaluate] can treat a
/// seeded/enrolled user as able-to-challenge (`canChallenge = available ||
/// hasPin`) even on the production `UnavailableBiometricGateway`. This is what
/// lets the debug-only [SessionSeamBootstrap]
/// (`jeeb.seam.session=biometric_enrolled`) deterministically hold the user on
/// `/lock`. The key defaults to absent → `hasPin == false`, preserving prior
/// behaviour for un-seeded users.
///
/// NOTE: this is a DEV/mock-grade store (plaintext SharedPreferences). A real
/// PIN must be salted+hashed in the keystore — tracked under T-mobile-005.
class SharedPrefsPinRepository {
  SharedPrefsPinRepository({required SharedPreferences prefs}) : _prefs = prefs;

  /// SharedPreferences key for the local PIN. Public so the dev-seam bootstrap
  /// seeds the SAME key this repo reads.
  static const String kPinKey = 'biometric.pin';

  final SharedPreferences _prefs;

  Future<bool> hasPin() async {
    final pin = _prefs.getString(kPinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _prefs.setString(kPinKey, pin);
  }

  Future<bool> verifyPin(String pin) async => _prefs.getString(kPinKey) == pin;
}
