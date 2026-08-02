import 'package:shared_preferences/shared_preferences.dart';

/// Persisted dev-tool override for gateway base URL. Read on DI Dio construction;
/// when unset, build-time JEEB_MOCK_BASE_URL default applies. Wiped by Dev Tool
abstract final class DevBaseUrl {
  static const String prefsKey = 'dev.base_url_override';

  /// Override, or null when unset/blank (use build-time default).
  static String? read(SharedPreferences prefs) {
    final value = prefs.getString(prefsKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> write(SharedPreferences prefs, String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(prefsKey);
    } else {
      await prefs.setString(prefsKey, trimmed);
    }
  }
}
