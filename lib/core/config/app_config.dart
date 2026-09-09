import 'package:flutter/foundation.dart'
    show kDebugMode, kProfileMode, kReleaseMode;

enum AppBuildMode { debug, profile, release }

/// Build-time app configuration resolved from `--dart-define` constants.
class AppConfig {
  AppConfig._();

  /// Build flavor used to separate development-only native/source policies.
  static const String appFlavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'production',
  );

  static bool get isDevelopmentFlavor => appFlavor == 'dev';

  /// Base URL of the live jeeb-gateway BFF. Production must inject it explicitly.
  /// ORIGIN-ONLY: scheme + host (+ port), NO `/v1`, no trailing slash. Every
  /// request path carries exactly one `/v1`; the empty default fails closed.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: '',
  );

  /// Device-reachable Phoenix WebSocket URL for live location tracking only.
  /// Chat uses chat-service-owned Firebase/Firestore and never reads this value.
  ///
  /// Staging and production builds must inject this explicitly. The empty
  /// default is intentional: realtime fails closed instead of guessing a host.
  static const String realtimeSocketUrl = String.fromEnvironment(
    'JEEB_REALTIME_SOCKET_URL',
    defaultValue: '',
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

  /// Compile-time kill switch for Microsoft Clarity session analytics.
  ///
  /// This defaults off. A valid public project ID must be supplied separately;
  /// the project ID is routing configuration, not a credential.
  static const bool clarityEnabled = bool.fromEnvironment(
    'JEEB_CLARITY_ENABLED',
    defaultValue: false,
  );

  /// Public Microsoft Clarity project identifier. Deliberately has no committed
  /// default so a build cannot accidentally send data to any project.
  static const String clarityProjectId = String.fromEnvironment(
    'JEEB_CLARITY_PROJECT_ID',
    defaultValue: '',
  );

  /// Release-owner assertion that privacy, minor-use, and store-disclosure
  /// gates have been approved for this build. It deliberately defaults off.
  static const bool clarityPrivacyApproved = bool.fromEnvironment(
    'JEEB_CLARITY_PRIVACY_APPROVED',
    defaultValue: false,
  );

  /// Owner-authorized internal staging validation only; this is not production
  /// privacy, minor-use or store-disclosure approval. Consent remains required.
  static const bool clarityStagingInternalApproved = bool.fromEnvironment(
    'JEEB_CLARITY_STAGING_INTERNAL_APPROVED',
    defaultValue: false,
  );
  static const bool _internalRelease = bool.fromEnvironment(
    'JEEB_INTERNAL_RELEASE',
    defaultValue: false,
  );

  /// Whether all release-owner gates form a valid Clarity configuration.
  static bool get clarityBuildConfigured =>
      clarityEnabled &&
      (clarityPrivacyApproved || _stagingClarityConfigured) &&
      _isValidClarityProjectId(clarityProjectId);

  /// Runtime availability is release-only. Debug, profile, test, CI and the
  /// devtool remain unable to start the SDK even if defines are supplied.
  static bool get clarityAvailable => clarityPolicyAllowsCapture(
    buildMode: _currentBuildMode,
    enabled: clarityEnabled,
    privacyApproved: clarityPrivacyApproved,
    projectId: clarityProjectId,
    stagingInternalApproved: clarityStagingInternalApproved,
    internalRelease: _internalRelease,
    flavor: appFlavor,
    gateway: gatewayBaseUrl,
    realtime: realtimeSocketUrl,
  );

  static bool get _stagingClarityConfigured => stagingClarityPolicyAllows(
    approved: clarityStagingInternalApproved,
    internalRelease: _internalRelease,
    flavor: appFlavor,
    gateway: gatewayBaseUrl,
    realtime: realtimeSocketUrl,
    projectId: clarityProjectId,
  );

  static bool stagingClarityPolicyAllows({
    required bool approved,
    required bool internalRelease,
    required String flavor,
    required String gateway,
    required String realtime,
    required String projectId,
  }) =>
      approved &&
      internalRelease &&
      flavor == 'staging' &&
      gateway == 'https://app.jeeb.fds-1.com' &&
      realtime == 'wss://app.jeeb.fds-1.com/socket/websocket' &&
      projectId == 'y6laxxj143';

  /// Pure policy seam used by production and its privacy truth-table tests.
  static bool clarityPolicyAllowsCapture({
    required AppBuildMode buildMode,
    required bool enabled,
    required bool privacyApproved,
    required String projectId,
    bool stagingInternalApproved = false,
    bool internalRelease = false,
    String flavor = 'production',
    String gateway = '',
    String realtime = '',
  }) =>
      buildMode == AppBuildMode.release &&
      enabled &&
      (privacyApproved ||
          stagingClarityPolicyAllows(
            approved: stagingInternalApproved,
            internalRelease: internalRelease,
            flavor: flavor,
            gateway: gateway,
            realtime: realtime,
            projectId: projectId,
          )) &&
      _isValidClarityProjectId(projectId);

  static AppBuildMode get _currentBuildMode => kReleaseMode
      ? AppBuildMode.release
      : kProfileMode
      ? AppBuildMode.profile
      : AppBuildMode.debug;

  static bool _isValidClarityProjectId(String value) =>
      value.isNotEmpty &&
      value == value.trim() &&
      RegExp(r'^[a-z0-9]+$').hasMatch(value);

  /// Build-time override. Supplied via `--dart-define=JEEB_SUPERADMIN_PASSCODE=<value>`.
  static const String _superAdminPassCodeDefine = String.fromEnvironment(
    'JEEB_SUPERADMIN_PASSCODE',
  );

  /// Debug-only resolution. There is deliberately no committed fallback, and
  /// release/profile builds cannot surface a supplied development credential.
  static String get superAdminPassCode =>
      kDebugMode ? _superAdminPassCodeDefine : '';

  /// DEBUG-ONLY convenience userId pre-filled into the PLAIN "Super login" sheet.
  static String get devSuperLoginUserId =>
      kDebugMode ? 'd1000000-0000-4000-8000-000000000001' : '';
}
