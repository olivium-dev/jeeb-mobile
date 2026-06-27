import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/account_service.dart';

/// Dio-backed [AccountService] for the settings surface (T-mobile-031).
///
/// Replaces the prior `FakeAccountService` as the DI default so the settings
/// screen's destructive actions hit the real jeeb-gateway instead of always
/// returning success. Speaks the gateway contract paths only — the
/// `MockGatewayClient` rewrite interceptor maps them to the `:4010` service
/// prefixes (40_GUARDRAILS_ARCH §4/§11: never hardcode a service prefix/host).
///
/// Unlike the fail-safe [AccountSessionTerminator] seam (JM-062, which always
/// drops the local session even when the network call fails), this seam
/// surfaces the network outcome to the cubit so the settings UI can render a
/// `networkError` banner. The local token clear still runs on the success path
/// of [signOut] so the session is genuinely dropped.
class DioAccountService implements AccountService {
  DioAccountService(this._dio, this._tokenStore);

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  /// `PATCH /users/{userId}/status { status: 'deleted' }` (D5). A 409 from the
  /// gateway means a deletion is already queued → [AccountActionOutcome.alreadyPending]
  /// so the cubit latches the row without re-firing. Any transport/5xx failure
  /// maps to [AccountActionOutcome.networkError].
  @override
  Future<AccountActionOutcome> requestAccountDeletion() async {
    try {
      final userId = await _tokenStore.userId;
      if (userId == null) return AccountActionOutcome.networkError;
      await _dio.patch<void>(
        '/v1/users/$userId/status',
        data: const <String, dynamic>{'status': 'deleted'},
      );
      return AccountActionOutcome.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return AccountActionOutcome.alreadyPending;
      }
      return AccountActionOutcome.networkError;
    } catch (_) {
      return AccountActionOutcome.networkError;
    }
  }

  /// `POST /v1/auth/logout { refreshToken }` → 2xx. On success the local
  /// keystore is cleared so the session is actually dropped. A transport/5xx
  /// failure maps to [AccountActionOutcome.networkError] and the local session
  /// is left intact (the cubit surfaces the error; the user stays signed in).
  @override
  Future<AccountActionOutcome> signOut() async {
    try {
      final refreshToken = await _tokenStore.refreshToken;
      await _dio.post<void>(
        '/v1/auth/logout',
        data: <String, dynamic>{'refreshToken': ?refreshToken},
      );
      await _tokenStore.clear();
      return AccountActionOutcome.success;
    } on DioException catch (_) {
      return AccountActionOutcome.networkError;
    } catch (_) {
      return AccountActionOutcome.networkError;
    }
  }
}
