import 'package:shared_preferences/shared_preferences.dart';

/// Stub created by sanity-build pass (2026-05-17).
///
/// app.dart constructs this with `{required SharedPreferences prefs}`. The
/// real persistence layer (the `biometric_enabled` flag) was never committed
/// — this stub returns `false` so the lock cubit defaults to "disabled" and
/// the router never holds the user on /lock.
class BiometricPreferenceRepositoryImpl {
  BiometricPreferenceRepositoryImpl({required SharedPreferences prefs})
      : _prefs = prefs;

  // ignore: unused_field
  final SharedPreferences _prefs;

  Future<bool> isEnabled() async => false;
  Future<void> setEnabled(bool value) async {}
}
