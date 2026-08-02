import 'package:flutter/foundation.dart' show kDebugMode;

/// Build-time app configuration resolved from `--dart-define` constants.
class AppConfig {
  AppConfig._();

  /// Base URL of the live jeeb-gateway BFF. ORIGIN-ONLY: scheme + host (+ port),
  /// NO `/v1`, no trailing slash. Every request path carries exactly one `/v1`;
  /// Dio merges `baseUrl + path`, so a `/v1` here doubles to `/v1/v1`.
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
  static const bool realtimeCourierPositionEnabled = bool.fromEnvironment(
    'JEEB_REALTIME_TRACKING',
    defaultValue: false,
  );

  /// Build-time override. Supplied via `--dart-define=JEEB_SUPERADMIN_PASSCODE=<value>`.
  static const String _superAdminPassCodeDefine = String.fromEnvironment(
    'JEEB_SUPERADMIN_PASSCODE',
  );

  /// Committed dev fallback = the REAL passcode the dev gateway
  /// (`http://192.168.2.39:10090`) validates `super-login/users` +
  /// `user-id-login` against (host env `SuperAdmin__PassCode`, length 6).
  ///
  /// SECURITY / RELEASE-SAFETY: this constant is a dev-backend-only secret. It
  /// is referenced ONLY inside the `kDebugMode` branch of [superAdminPassCode]
  /// below. In a release build `kDebugMode` is a compile-time `false`, so that
  /// branch — and therefore the only reference to this constant — is
  /// dead-code-eliminated by the Dart AOT compiler and the literal never ships
  /// in the release binary. Do NOT reference this field anywhere outside a
  /// `kDebugMode`/`assert` guard, and NEVER log it.
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
