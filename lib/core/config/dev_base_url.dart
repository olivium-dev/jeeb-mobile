import 'package:shared_preferences/shared_preferences.dart';

import '../dev_flags.dart';

/// Persisted dev-tool override for gateway base URL. Read on DI Dio construction;
/// when unset, build-time JEEB_MOCK_BASE_URL default applies. Wiped by Dev Tool
abstract final class DevBaseUrl {
  static const String prefsKey = 'dev.base_url_override';

  /// Override, or null when unset/blank (use build-time default).
  static String? read(SharedPreferences prefs) => resolve(
    overrideAllowed: kDevAffordancesAllowed,
    persistedValue: prefs.getString(prefsKey),
  );

  static String? resolve({
    required bool overrideAllowed,
    required String? persistedValue,
  }) {
    if (!overrideAllowed) return null;
    final value = persistedValue?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> write(SharedPreferences prefs, String? url) =>
      writeForBuild(prefs, url, overrideAllowed: kDevAffordancesAllowed);

  static Future<void> writeForBuild(
    SharedPreferences prefs,
    String? url, {
    required bool overrideAllowed,
  }) async {
    if (!overrideAllowed) {
      await prefs.remove(prefsKey);
      return;
    }
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, trimmed);
    }
  }
}
