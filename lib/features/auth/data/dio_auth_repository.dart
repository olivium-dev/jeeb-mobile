import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/auth_repository.dart';

/// [AuthRepository] backed by the gateway BFF. Routes verified by W-1 FLOOR contract.
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

  /// Persists JWT pair; `user.userId` is the alias the mock places next to `id`.
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

  /// Maps DioException to AuthFailure: timeout/network → network, 401 codes → auth-specific,
  /// 400 → badRequest, else unknown.
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
    // Signup find-or-create collision (D22): mock tags code: email_collision; treat any 409 as collision.
    if (status == 409) return AuthFailure.emailCollision;
    if (status == 400) return AuthFailure.badRequest;
    return AuthFailure.unknown;
  }

  /// Reads RFC-7807 `code` field from ProblemError, tolerating `title`/`type` aliases.
  static String? _problemCode(Object? data) {
    if (data is Map) {
      final code = data['code'] ?? data['title'] ?? data['type'];
      return code is String ? code : null;
    }
    return null;
  }
}
