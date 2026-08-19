import 'package:shared_preferences/shared_preferences.dart';

const String kDevelopmentGatewayBaseUrl = 'http://192.168.2.39:10090';
const String kStagingGatewayBaseUrl = 'https://app.jeeb.fds-1.com';

enum DevBackendEnvironment {
  development(
    id: 'dev',
    label: 'Development',
    description: 'Local MSI gateway',
    baseUrl: kDevelopmentGatewayBaseUrl,
  ),
  staging(
    id: 'staging',
    label: 'Staging',
    description: 'Public Cloudflare gateway',
    baseUrl: kStagingGatewayBaseUrl,
  );

  const DevBackendEnvironment({
    required this.id,
    required this.label,
    required this.description,
    required this.baseUrl,
  });

  final String id;
  final String label;
  final String description;
  final String baseUrl;

  static DevBackendEnvironment? fromId(String? id) {
    for (final environment in values) {
      if (environment.id == id) return environment;
    }
    return null;
  }

  static DevBackendEnvironment? fromBaseUrl(String? baseUrl) {
    final normalized = DevBaseUrl.normalize(baseUrl);
    for (final environment in values) {
      if (DevBaseUrl.normalize(environment.baseUrl) == normalized) {
        return environment;
      }
    }
    return null;
  }
}

/// Persisted dev-tool override for gateway base URL. Read on DI Dio construction;
/// when unset, build-time JEEB_MOCK_BASE_URL default applies. Wiped by Dev Tool
abstract final class DevBaseUrl {
  static const String prefsKey = 'dev.base_url_override';
  static const String environmentPrefsKey = 'dev.backend_environment';
  static const String appliedBaseUrlPrefsKey = 'dev.applied_base_url';

  /// Override, or null when unset/blank (use build-time default).
  static String? read(SharedPreferences prefs) {
    final environment = DevBackendEnvironment.fromId(
      prefs.getString(environmentPrefsKey),
    );
    if (environment != null) return environment.baseUrl;
    final value = prefs.getString(prefsKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Reads the named environment. Existing URL-only preferences are migrated
  /// logically by matching their URL, so older installs keep their selection.
  static DevBackendEnvironment? readEnvironment(SharedPreferences prefs) {
    return DevBackendEnvironment.fromId(prefs.getString(environmentPrefsKey)) ??
        DevBackendEnvironment.fromBaseUrl(read(prefs));
  }

  static String? normalize(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Returns a canonical HTTP(S) origin, or null when [url] contains anything
  /// that would make Dio join request paths ambiguously.
  static String? canonicalOrigin(String? url) {
    final trimmed = url?.trim() ?? '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    return uri.replace(path: '').toString();
  }

  /// Binds persisted credentials to the backend that will run this launch.
  /// Clearing happens before the applied marker advances, so a keychain error
  /// fails closed and prevents bootstrap from continuing with a mixed session.
  static Future<void> activateForLaunch(
    SharedPreferences prefs, {
    required String defaultBaseUrl,
    required Future<void> Function() clearCredentials,
  }) async {
    final selected = read(prefs) ?? defaultBaseUrl;
    final applied = prefs.getString(appliedBaseUrlPrefsKey);
    final hasExplicitSelection =
        prefs.containsKey(environmentPrefsKey) || prefs.containsKey(prefsKey);
    final changed = applied == null
        ? hasExplicitSelection &&
              normalize(selected) != normalize(defaultBaseUrl)
        : normalize(selected) != normalize(applied);
    if (changed) await clearCredentials();
    await prefs.setString(appliedBaseUrlPrefsKey, selected);
  }

  static Future<void> selectEnvironment(
    SharedPreferences prefs,
    DevBackendEnvironment environment,
  ) async {
    await prefs.setString(environmentPrefsKey, environment.id);
    await prefs.setString(prefsKey, environment.baseUrl);
  }

  static Future<void> write(SharedPreferences prefs, String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(prefsKey);
      await prefs.remove(environmentPrefsKey);
    } else {
      await prefs.setString(prefsKey, trimmed);
      final environment = DevBackendEnvironment.fromBaseUrl(trimmed);
      if (environment == null) {
        await prefs.remove(environmentPrefsKey);
      } else {
        await prefs.setString(environmentPrefsKey, environment.id);
      }
    }
  }
}
