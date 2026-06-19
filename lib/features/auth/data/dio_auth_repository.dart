import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/auth_repository.dart';

/// [AuthRepository] backed by the Express mock auth-service via the gateway
/// rewrite (B1: `/v1/auth/*` → `/auth-service/auth/*`). Every path is the
/// VERIFIED W-1 FLOOR contract (42_GUARDRAILS_MOCK §"W-1 FLOOR CLOSED"):
///
///   POST /v1/auth/login            { email, password }      → { accessToken, refreshToken, user }
///   POST /v1/auth/recovery/request { email }                → { requestId, expiresInSeconds: 600 }
///   POST /v1/auth/recovery/verify  { email, code }          → { resetToken, expiresInSeconds: 600 }
///   POST /v1/auth/set-password     { email, password, resetToken? } → { accessToken, refreshToken, user }
///
/// `MockGatewayClient` rewrites the `/v1/auth/*` prefix to the `:4010` service
/// prefix — the repo never hardcodes a host/prefix (40_GUARDRAILS §4). On a
/// successful login/set-password the JWT pair is persisted to [AuthTokenStore]
/// (reading `user.userId` for splash session-routing, JM-006).
class DioAuthRepository implements AuthRepository {
  const DioAuthRepository(this._dio, this._tokenStore);

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/signup',
        data: {
          'email': email,
          'password': password,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      return _persistAndBuildSession(res.data);
    } on DioException catch (e) {
      throw AuthRepositoryException(_mapAuth(e));
    }
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return _persistAndBuildSession(res.data);
    } on DioException catch (e) {
      throw AuthRepositoryException(_mapAuth(e));
    }
  }

  @override
  Future<RecoveryRequestResult> requestRecovery({
    required String email,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/recovery/request',
        data: {'email': email},
      );
      final body = res.data ?? const {};
      return RecoveryRequestResult(
        expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 600,
      );
    } on DioException catch (e) {
      throw AuthRepositoryException(_mapAuth(e));
    }
  }

  @override
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/recovery/verify',
        data: {'email': email, 'code': code},
      );
      final body = res.data ?? const {};
      final resetToken = body['resetToken'] as String?;
      if (resetToken == null || resetToken.isEmpty) {
        throw const AuthRepositoryException(AuthFailure.unknown);
      }
      return RecoveryVerifyResult(
        resetToken: resetToken,
        expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 600,
      );
    } on DioException catch (e) {
      throw AuthRepositoryException(_mapAuth(e));
    }
  }

  @override
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/set-password',
        data: {
          'email': email,
          'password': password,
          if (resetToken != null && resetToken.isNotEmpty)
            'resetToken': resetToken,
        },
      );
      return _persistAndBuildSession(res.data);
    } on DioException catch (e) {
      throw AuthRepositoryException(_mapAuth(e));
    }
  }

  /// Persists the JWT pair and returns the [AuthSession]. `user.userId` is the
  /// alias the mock places next to `id` on every bundle (W-1 FLOOR).
  Future<AuthSession> _persistAndBuildSession(Map<String, dynamic>? body) async {
    final data = body ?? const {};
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    final userId = (user?['userId'] ?? user?['id']) as String?;
    if (access == null || refresh == null || userId == null) {
      throw const AuthRepositoryException(AuthFailure.unknown);
    }
    await _tokenStore.save(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
    return AuthSession(
      userId: userId,
      email: user?['email'] as String?,
      status: user?['status'] as String?,
    );
  }

  /// Maps a [DioException] to a typed [AuthFailure]. Connection/timeout →
  /// network; the documented 401 `code` values discriminate the auth legs;
  /// 400 → badRequest; everything else → unknown (40_GUARDRAILS §4).
  AuthFailure _mapAuth(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AuthFailure.network;
    }
    final status = e.response?.statusCode;
    final code = _problemCode(e.response?.data);
    if (status == 401) {
      switch (code) {
        case 'invalid_recovery_code':
          return AuthFailure.invalidRecoveryCode;
        case 'invalid_token':
          return AuthFailure.invalidToken;
        case 'invalid_credentials':
        default:
          return AuthFailure.invalidCredentials;
      }
    }
    // Signup find-or-create collision (D22). The mock tags the body `code:
    // email_collision`; treat any 409 on the signup leg as a collision so the
    // screen can route to the social-collision prompt (JM-019).
    if (status == 409) return AuthFailure.emailCollision;
    if (status == 400) return AuthFailure.badRequest;
    return AuthFailure.unknown;
  }

  /// Reads the RFC-7807 `code` field from a `ProblemError` body, tolerating the
  /// `title`/`type` aliases the mock may use. Null when absent/non-map.
  static String? _problemCode(Object? data) {
    if (data is Map) {
      final code = data['code'] ?? data['title'] ?? data['type'];
      return code is String ? code : null;
    }
    return null;
  }
}
