/// Build-time application configuration.
///
/// Every value is resolved from a `--dart-define` at compile time so the
/// gateway host and the mock toggle are never hard-coded in the binary and
/// can be flipped per build/CI lane:
///
///   --dart-define=GATEWAY_BASE_URL=https://api.jeeb.app/v1
///   --dart-define=USE_MOCK_GATEWAY=true   # local Express-mock dev only
///
/// The defaults are production-safe: a release/device build with no defines
/// talks to the real gateway over the real Dio client (see [DioClient]).
class AppConfig {
  const AppConfig._();

  /// Base URL of the live jeeb-gateway BFF. The app speaks ONLY to the gateway
  /// (never a backend service directly). Defaults to the production gateway.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: 'https://api.jeeb.app/v1',
  );

  /// When `true`, DI registers the local Express-mock-backed [Dio] client
  /// (`MockGatewayClient.createDio()`) instead of the real gateway client.
  /// Defaults to `false` so the real Dio impl is the default everywhere.
  static const bool useMockGateway = bool.fromEnvironment(
    'USE_MOCK_GATEWAY',
    defaultValue: false,
  );
}
