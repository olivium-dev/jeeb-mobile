/// Build-time application configuration.
///
/// Every value is resolved from a `--dart-define` at compile time so the
/// gateway host and the mock toggle are never hard-coded in the binary and
/// can be flipped per build/CI lane:
///
///   --dart-define=GATEWAY_BASE_URL=https://api.jeeb.app   # ORIGIN ONLY, no /v1
///   --dart-define=USE_MOCK_GATEWAY=true   # local Express-mock dev only
///
/// The defaults are production-safe: a release/device build with no defines
/// talks to the real gateway over the real Dio client (see [DioClient]).
class AppConfig {
  const AppConfig._();

  /// Base URL of the live jeeb-gateway BFF. The app speaks ONLY to the gateway
  /// (never a backend service directly). Defaults to the production gateway.
  ///
  /// FROZEN (ARCH-01 / INFRA-01): this is ORIGIN-ONLY — scheme + host + (port),
  /// with NO `/v1` path segment and NO trailing slash. Every feature request
  /// path carries its own single `/v1` (e.g. `/v1/users/me`,
  /// `/v1/jeebers/me/availability`), so Dio's `baseUrl + path` concatenation
  /// yields exactly one `/v1`. The prior default (`https://api.jeeb.app/v1`)
  /// doubled it to `/v1/v1/...` against the real gateway — the S16 availability
  /// NO-GO root cause — and only escaped notice because the mock base is
  /// origin-only. Keep this origin-only; never re-add `/v1` here. The anti-drift
  /// contract test (`test/core/config/base_url_convention_test.dart`) asserts
  /// this default does NOT end in `/v1` and that a representative resolved URL
  /// contains exactly one `/v1`.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: 'https://api.jeeb.app',
  );

  /// When `true`, DI registers the local Express-mock-backed [Dio] client
  /// (`MockGatewayClient.createDio()`) instead of the real gateway client.
  /// Defaults to `false` so the real Dio impl is the default everywhere.
  static const bool useMockGateway = bool.fromEnvironment(
    'USE_MOCK_GATEWAY',
    defaultValue: false,
  );

  /// Whether the email + password auth funnel (login `POST /v1/auth/login` and
  /// sign-up `POST /v1/auth/signup`) is reachable from the UI.
  ///
  /// The LIVE jeeb-gateway does not serve these routes — they `401` in
  /// production — so the email login form and the sign-up link are dead-ends
  /// against the real backend. The phone-OTP funnel (`/register`,
  /// `POST /v1/auth/otp/request` → `/v1/auth/otp/verify`) is the only auth that
  /// works there. When this flag is `false` the email surfaces are hidden and
  /// the screen routes the user to phone-OTP, keeping the app honest.
  ///
  /// Defaults to [useMockGateway]: the local Express mock DOES implement the
  /// email routes (the `jm-007`/`jm-008` Maestro flows exercise them), so a
  /// `--dart-define=USE_MOCK_GATEWAY=true` dev/CI build keeps email auth live,
  /// while a default production/device build (real gateway) guards it. Override
  /// explicitly with `--dart-define=EMAIL_PASSWORD_AUTH_ENABLED=true` once the
  /// gateway serves the routes.
  static const bool emailPasswordAuthEnabled = bool.fromEnvironment(
    'EMAIL_PASSWORD_AUTH_ENABLED',
    defaultValue: useMockGateway,
  );
}
