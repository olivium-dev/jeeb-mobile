import 'package:dio/dio.dart';

/// Error categories surfaced by [SuperLoginService.signIn].
///
/// The UI never distinguishes *which* credential was wrong (user-id vs
/// passcode) — both map to [invalidCredentials] so an attacker cannot probe
/// valid user ids. Transport problems map to [network]; everything else to
/// [unknown].
enum SuperLoginError { invalidCredentials, network, unknown }

/// A real, gateway-minted super-user session. The tokens here come from the
/// server in exchange for a submitted passcode — they are NEVER a hardcoded
/// `mock-jwt-*` string minted client-side.
class SuperLoginSession {
  const SuperLoginSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String accessToken;

  /// The gateway super-login route may omit a refresh token (it returns only
  /// `{userId, authToken}`); callers fall back to the access token so the
  /// secure store always has a non-null refresh slot.
  final String refreshToken;
}

/// Result of a single super-login attempt.
sealed class SuperLoginResult {
  const SuperLoginResult();
}

class SuperLoginSuccess extends SuperLoginResult {
  const SuperLoginSuccess(this.session);
  final SuperLoginSession session;
}

class SuperLoginFailure extends SuperLoginResult {
  const SuperLoginFailure(this.error);
  final SuperLoginError error;
}

/// Validates a super-user credential against the gateway and returns the
/// real minted session. Mirrors [SocialAuthService] in shape so the two
/// dev/auth entry points share one mental model.
///
/// Contract (Rahma `SuperUserModel` parity, FR-P0-4 / DESIGN-FIRST-RUN §2d):
/// `POST /api/User/user-id-login` with body
/// `{ "userId": ..., "superAdminPassCode": ... }`, expecting
/// `{ "userId": ..., "authToken": ..., "refreshToken"?: ... }`.
///
/// SECURITY: the passcode is sent over the wire and is NEVER logged or
/// compared client-side.
abstract class SuperLoginService {
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  });
}

/// Production / mock-backend implementation backed by a [Dio] client.
class DefaultSuperLoginService implements SuperLoginService {
  DefaultSuperLoginService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Gateway super-login route. Returns `SocialLoginResponse{userId,authToken}`
  /// on the mock (`:3055`) and a real session in production.
  static const String _endpoint = '/api/User/user-id-login';

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        data: <String, dynamic>{
          'userId': userId,
          // Rahma's wire field name — the server validates this passcode.
          'superAdminPassCode': passcode,
        },
      );
      final data = response.data;
      if (data == null) {
        return const SuperLoginFailure(SuperLoginError.unknown);
      }
      final session = _parseSession(data);
      if (session == null) {
        return const SuperLoginFailure(SuperLoginError.invalidCredentials);
      }
      return SuperLoginSuccess(session);
    } on DioException catch (e) {
      return SuperLoginFailure(_mapDioError(e));
    }
  }

  SuperLoginSession? _parseSession(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    final accessToken = data['authToken'] as String?;
    if (userId == null ||
        userId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      return null;
    }
    final refreshToken = data['refreshToken'] as String?;
    return SuperLoginSession(
      userId: userId,
      accessToken: accessToken,
      // The super-login route may not issue a refresh token; reuse the access
      // token so AuthTokenStore.save (refreshToken required) always succeeds.
      refreshToken:
          (refreshToken != null && refreshToken.isNotEmpty)
              ? refreshToken
              : accessToken,
    );
  }

  SuperLoginError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return SuperLoginError.network;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        // 400/401/403 => the server rejected the credential.
        if (status == 400 || status == 401 || status == 403) {
          return SuperLoginError.invalidCredentials;
        }
        if (status >= 500) return SuperLoginError.network;
        return SuperLoginError.unknown;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return SuperLoginError.unknown;
    }
  }
}
