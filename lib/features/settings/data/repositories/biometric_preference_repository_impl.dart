import 'package:shared_preferences/shared_preferences.dart';

class BiometricPreferenceRepositoryImpl {
  BiometricPreferenceRepositoryImpl({required SharedPreferences prefs})
      : _prefs = prefs;

  static const String kEnabledKey = 'biometric.enabled';

  final SharedPreferences _prefs;

  Future<bool> isEnabled() async => _prefs.getBool(kEnabledKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(kEnabledKey, value);
  }
}
