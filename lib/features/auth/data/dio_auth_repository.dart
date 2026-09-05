import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/gateway_problem.dart';
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

  /// Classifies through [AppFailure] so a 5xx reads as a server fault, never
  /// as the caller's connection; 401s are split by the problem's type suffix.
  AuthFailure _mapAuth(DioException e) {
    final failure = AppFailure.of(e);
    return switch (failure) {
      NetworkFailure() || TimeoutFailure() => AuthFailure.network,
      UnauthorizedFailure(:final GatewayProblem? problem) =>
        switch (problem?.typeSuffix) {
          'invalid_recovery_code' => AuthFailure.invalidRecoveryCode,
          'invalid_token' => AuthFailure.invalidToken,
          _ => AuthFailure.invalidCredentials,
        },
      // Signup find-or-create collision (D22): any 409 is a collision.
      ConflictFailure() => AuthFailure.emailCollision,
      ValidationFailure() => AuthFailure.badRequest,
      ServerFailure() => AuthFailure.serverError,
      RateLimitedFailure() => AuthFailure.rateLimited,
      _ => AuthFailure.unknown,
    };
  }
}
