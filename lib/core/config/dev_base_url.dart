import 'package:shared_preferences/shared_preferences.dart';

/// Persisted, Dev-Tool-settable override for the gateway base URL (F4).
///
/// The DI graph reads [read] when constructing the `Dio` client, so a value set
/// here (via the Dev Tool → Server URL screen) points the whole app at a
/// different backend on the next app start. When unset, the build-time
/// `JEEB_MOCK_BASE_URL` default applies. Stored in [SharedPreferences] so it is
/// wiped by the Dev Tool's "Clear Local Data" (F5).
abstract final class DevBaseUrl {
  static const String prefsKey = 'dev.base_url_override';

  /// The override, or `null` when unset/blank (→ use the build-time default).
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
