import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "biometric unlock enabled" preference (D23).
///
/// Originally a sanity-build stub that hard-returned `false`; it now reads and
/// writes a real [SharedPreferences] flag so the preference survives launches
/// AND so the debug-only [SessionSeamBootstrap] can seed it
/// (`jeeb.seam.session=biometric_enrolled*`) before the router's biometric gate
/// evaluates. The key defaults to absent → `false`, so the prior "never hold on
/// /lock" behaviour is unchanged for any user who has not opted in / been
/// seeded.
class BiometricPreferenceRepositoryImpl {
  BiometricPreferenceRepositoryImpl({required SharedPreferences prefs})
      : _prefs = prefs;

  /// SharedPreferences key for the biometric-unlock opt-in flag. Public so the
  /// dev-seam bootstrap seeds the SAME key this repo reads (single source of
  /// truth — no second store to drift).
  static const String kEnabledKey = 'biometric.enabled';

  final SharedPreferences _prefs;

  Future<bool> isEnabled() async => _prefs.getBool(kEnabledKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(kEnabledKey, value);
  }
}
