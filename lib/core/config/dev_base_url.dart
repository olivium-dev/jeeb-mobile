import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted dev-tool override for gateway base URL. Read on DI Dio construction;
/// when unset, build-time JEEB_MOCK_BASE_URL default applies. Wiped by Dev Tool
abstract final class DevBaseUrl {
  static const String prefsKey = 'dev.base_url_override';

  /// Override, or null when unset/blank (use build-time default).
  static String? read(SharedPreferences prefs) => resolve(
    debugBuild: kDebugMode,
    persistedValue: prefs.getString(prefsKey),
  );

  static String? resolve({
    required bool debugBuild,
    required String? persistedValue,
  }) {
    if (!debugBuild) return null;
    final value = persistedValue?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> write(SharedPreferences prefs, String? url) =>
      writeForBuild(prefs, url, debugBuild: kDebugMode);

  static Future<void> writeForBuild(
    SharedPreferences prefs,
    String? url, {
    required bool debugBuild,
  }) async {
    if (!debugBuild) {
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
