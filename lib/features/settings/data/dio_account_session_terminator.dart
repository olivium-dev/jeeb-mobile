import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/account_session_terminator.dart';

/// Dio-backed [AccountSessionTerminator] for the logout / delete-account
/// confirm surface (JM-062).
///
/// Speaks the gateway contract paths (`/v1/auth/logout`, `/v1/devices/...`);
/// `MockGatewayClient`'s rewrite interceptor maps them to the `:4010` service
/// prefixes (`/auth-service/auth/logout`, `/push-notification/v1/devices/...`).
/// Never hardcodes a service prefix or host (40_GUARDRAILS_ARCH §4/§11).
///
/// **Fail-safe contract (D5):** the gateway calls are wrapped so a transport
/// failure (offline, 4xx/5xx, missing route) can never prevent the local
/// keystore clear. The local clear is what flips [SessionGate.isUnauthenticated]
/// → splash; a server that never hears the logout is acceptable (the token is
/// dead client-side), a user trapped in a logged-in shell is not.
class DioAccountSessionTerminator implements AccountSessionTerminator {
  DioAccountSessionTerminator(
    this._dio,
    this._tokenStore, {
    Future<String?> Function()? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider ?? _defaultDeviceIdProvider;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  /// Resolves the stable per-install device id to unregister on logout. Defaults
  /// to reading the `push.deviceId` key the [DeviceTokenRegistrar] persists to
  /// SharedPreferences; tests inject a fixed provider. Best-effort — a null id
  /// means "nothing registered", and the unregister hop is simply skipped.
  final Future<String?> Function() _deviceIdProvider;

  /// SharedPreferences key the device-token registrar persists the stable
  /// per-install device id under (`DeviceTokenRegistrar._deviceIdKey`).
  static const String _deviceIdPrefsKey = 'push.deviceId';

  static Future<String?> _defaultDeviceIdProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deviceIdPrefsKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await _revokeGatewaySession();
    await _unregisterPushDevice();
    // Load-bearing step (JM-062 AC / D5): drop the local session so the
    // router's first-run gate flips to unauthenticated and `/` → splash → login.
    await _clearLocalSession();
  }

  @override
  Future<void> deleteAccount() async {
    // Best-effort: queue the account for deletion (status → deleted, D5). The
    // app-client account-deletion gateway route is backend-owned (CTO-D2); if it
    // is not yet served the call no-ops fail-safe. Either way the local session
    // is cleared so the confirm lands on splash exactly like logout.
    await _requestAccountDeletion();
    await _unregisterPushDevice();
    await _clearLocalSession();
  }

  /// `POST /v1/auth/logout { refreshToken }` → 204 (W-1 FLOOR). Best-effort.
  Future<void> _revokeGatewaySession() async {
    try {
      final refreshToken = await _tokenStore.refreshToken;
      await _dio.post<void>(
        '/v1/auth/logout',
        data: <String, dynamic>{'refreshToken': ?refreshToken},
      );
    } catch (_) {
      // Swallow — local clear below is the load-bearing step (D5).
    }
  }

  /// `DELETE /api/PushNotification/device { deviceId }` → gateway
  /// `PushNotificationController.DeleteDevice` (the owning userId is derived
  /// server-side from the bearer, so only `deviceId` is sent). Replaces the dead
  /// `POST /v1/devices/unregister` (404 on the live gateway — it never removed
  /// the token, so pushes kept targeting the signed-out install). Best-effort:
  /// absence of a device id, an unmatched route, or any transport failure is
  /// non-fatal and never blocks the local session clear.
  Future<void> _unregisterPushDevice() async {
    try {
      final deviceId = await _deviceIdProvider();
      if (deviceId == null || deviceId.isEmpty) return;
      await _dio.delete<void>(
        '/api/PushNotification/device',
        data: <String, dynamic>{'deviceId': deviceId},
      );
    } catch (_) {
      // Swallow — device cleanup is non-blocking for the logout flow.
    }
  }

  /// `PATCH /users/:userId/status { status: 'deleted' }` (D5). Best-effort —
  /// the app-client deletion contract is backend-owned; a 404/4xx no-ops.
  Future<void> _requestAccountDeletion() async {
    try {
      final userId = await _tokenStore.userId;
      if (userId == null) return;
      await _dio.patch<void>(
        '/v1/users/$userId/status',
        data: const <String, dynamic>{'status': 'deleted'},
      );
    } catch (_) {
      // Swallow — local clear below is the load-bearing step (D5).
    }
  }

  Future<void> _clearLocalSession() async {
    try {
      await _tokenStore.clear();
    } catch (_) {
      // A keystore that refuses to clear cannot block the navigation; the
      // session gate fails CLOSED (an unreadable token → unauthenticated), so
      // splash still routes to login.
    }
  }
}
