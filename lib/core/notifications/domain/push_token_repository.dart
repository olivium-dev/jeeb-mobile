/// Push device-token registration with the gateway
/// (notif-push-token-registration).
///
/// Previously the FCM token was fetched into cubit state but NEVER POSTed to
/// register — only the logout `POST /v1/devices/unregister` existed. This port
/// registers the device so server-side notifications can target this install,
/// and re-registers when the token rotates (reinstall / restore).
///
/// **Gateway contract.** `MockGatewayClient` already maps `/v1/devices` →
/// `/push-notification/v1/devices`. Documented expected register shape:
///
///   POST /v1/devices
///     body: { token, platform: "ios"|"android", userId? }
///     → 200/201   (idempotent: same token re-POSTs are a no-op server-side)
abstract class PushTokenRepository {
  const PushTokenRepository();

  /// Registers the device [token] with the gateway. Best-effort — a failure
  /// must never crash the push chain; the caller swallows the error and retries
  /// on the next token refresh.
  Future<void> register(String token);
}
