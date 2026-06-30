import 'package:flutter/foundation.dart' show kDebugMode;

/// Build-time application configuration.
///
/// Values are resolved from `--dart-define` constants where possible so a
/// build can be retargeted without editing source. The single secret here is
/// the SuperAdmin passcode, which is DEBUG-ONLY (see [superAdminPassCode]).
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // Auth funnel feature flags
  // ---------------------------------------------------------------------------

  /// Whether the email + password auth funnel (login `POST /v1/auth/login` and
  /// sign-up `POST /v1/auth/signup`) is reachable from the UI.
  ///
  /// The LIVE jeeb-gateway (MSI native, `192.168.2.39:10090`) does not serve
  /// these routes — they `401` in production — so the email login form and the
  /// sign-up link are dead-ends against the real backend. The phone-OTP funnel
  /// (`/register`, `POST /v1/auth/otp/request` → `/v1/auth/otp/verify`) is the
  /// only auth that works there, so when this flag is `false` the email
  /// surfaces are hidden and the login screen promotes phone-OTP as the primary
  /// action, keeping the app honest.
  ///
  /// Defaults to `false` (the real gateway is the ground-truth backend). A
  /// build that points at a mock which DOES serve the email routes can flip it
  /// on with `--dart-define=EMAIL_PASSWORD_AUTH_ENABLED=true`.
  static const bool emailPasswordAuthEnabled = bool.fromEnvironment(
    'EMAIL_PASSWORD_AUTH_ENABLED',
    defaultValue: false,
  );

  // ---------------------------------------------------------------------------
  // SuperAdmin passcode (DEBUG-ONLY dev surface)
  // ---------------------------------------------------------------------------

  /// Build-time override. Supplied via
  /// `--dart-define=JEEB_SUPERADMIN_PASSCODE=<value>`. Empty when not passed.
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

  /// The single real SuperAdmin passcode used by the debug-only "Super user
  /// login" surfaces for BOTH (a) the passcode-gated active-user LIST call
  /// (`POST /api/User/super-login/users`) and (b) the tap→login
  /// (`POST /api/User/user-id-login`).
  ///
  /// Resolution order:
  ///   1. `--dart-define=JEEB_SUPERADMIN_PASSCODE` when supplied (any build).
  ///   2. In `kDebugMode` only: the committed dev fallback so a plain
  ///      `flutter run`/`flutter build apk --debug` with NO define still has a
  ///      working passcode (the owner's real scenario — never type it).
  ///   3. Empty in release (the surface is `kDebugMode`-gated out anyway, so a
  ///      release build carries no secret).
  static String get superAdminPassCode {
    if (_superAdminPassCodeDefine.isNotEmpty) return _superAdminPassCodeDefine;
    if (kDebugMode) return _devSuperAdminPassCode;
    return '';
  }

  /// DEBUG-ONLY convenience userId pre-filled into the PLAIN "Super login"
  /// sheet so that surface is also usable without typing. Points at the dev
  /// gateway's "Nour Demo" customer (verified `getMe` →
  /// `d1000000-0000-4000-8000-000000000001`). Empty in release.
  static String get devSuperLoginUserId =>
      kDebugMode ? 'd1000000-0000-4000-8000-000000000001' : '';
}
