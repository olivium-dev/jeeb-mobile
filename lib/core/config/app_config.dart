import 'package:flutter/foundation.dart' show kDebugMode;

/// Build-time app configuration resolved from `--dart-define` constants.
class AppConfig {
  AppConfig._();

  /// Base URL of the live jeeb-gateway BFF. ORIGIN-ONLY: scheme + host (+ port),
  /// NO `/v1`, no trailing slash. Every request path carries exactly one `/v1`;
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: 'https://api.jeeb.app',
  );

  /// Whether email + password auth is reachable from the UI.
  static const bool emailPasswordAuthEnabled = bool.fromEnvironment(
    'EMAIL_PASSWORD_AUTH_ENABLED',
    defaultValue: false,
  );

  /// Whether the customer's tracking map subscribes to realtime courier position.
  ///
  /// DEFAULT-ON since Phase V D14. Off-by-default meant no shipped build ever
  /// subscribed — only the two dev scripts passed the define — so the map moved
  /// only on push or re-open and a customer watched a frozen courier. The
  /// subscription degrades to exactly that old behaviour whenever the gateway
  /// cannot hand out a usable descriptor, so ON is the safe default.
  /// Kill switch: `--dart-define=JEEB_REALTIME_TRACKING=false`.
  static const bool realtimeCourierPositionEnabled = bool.fromEnvironment(
    'JEEB_REALTIME_TRACKING',
    defaultValue: true,
  );

  /// Build-time override. Supplied via `--dart-define=JEEB_SUPERADMIN_PASSCODE=<value>`.
  static const String _superAdminPassCodeDefine = String.fromEnvironment(
    'JEEB_SUPERADMIN_PASSCODE',
  );

  /// Committed dev fallback = the REAL passcode the dev gateway
  /// (`http://192.168.2.39:10090`) validates `super-login/users` +
  static const String _devSuperAdminPassCode = '123768';

  /// Resolution: `--dart-define` > `kDebugMode` fallback > empty in release.
  static String get superAdminPassCode {
    if (_superAdminPassCodeDefine.isNotEmpty) return _superAdminPassCodeDefine;
    if (kDebugMode) return _devSuperAdminPassCode;
    return '';
  }

  /// DEBUG-ONLY convenience userId pre-filled into the PLAIN "Super login" sheet.
  static String get devSuperLoginUserId =>
      kDebugMode ? 'd1000000-0000-4000-8000-000000000001' : '';
}
