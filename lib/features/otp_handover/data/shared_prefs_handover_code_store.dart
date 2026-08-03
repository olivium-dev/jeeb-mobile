import 'package:shared_preferences/shared_preferences.dart';

import '../domain/handover_code_store.dart';

class SharedPrefsHandoverCodeStore implements HandoverCodeStore {
  SharedPrefsHandoverCodeStore({required SharedPreferences prefs})
      : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'jeeb.handover_code.';

  static String _keyFor(String deliveryId) => '$_keyPrefix$deliveryId';

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    final trimmed = code.trim();
    if (deliveryId.isEmpty || trimmed.isEmpty) return;
    await _prefs.setString(_keyFor(deliveryId), trimmed);
  }

  @override
  Future<String?> read({required String deliveryId}) async {
    if (deliveryId.isEmpty) return null;
    final value = _prefs.getString(_keyFor(deliveryId));
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> clear({required String deliveryId}) async {
    if (deliveryId.isEmpty) return;
    await _prefs.remove(_keyFor(deliveryId));
  }
}
