import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsPinRepository {
  SharedPrefsPinRepository({required SharedPreferences prefs}) : _prefs = prefs;

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
