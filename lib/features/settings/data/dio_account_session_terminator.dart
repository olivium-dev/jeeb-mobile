import 'package:dio/dio.dart';

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
  DioAccountSessionTerminator(this._dio, this._tokenStore);

  final Dio _dio;
  final AuthTokenStore _tokenStore;

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

  /// `POST /v1/devices/unregister { userId }` → push-notification service.
  /// Best-effort; absence of the route or a transport failure is non-fatal.
  Future<void> _unregisterPushDevice() async {
    try {
      final userId = await _tokenStore.userId;
      await _dio.post<void>(
        '/v1/devices/unregister',
        data: <String, dynamic>{'userId': ?userId},
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
        '/users/$userId/status',
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
