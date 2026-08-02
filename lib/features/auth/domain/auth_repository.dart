// PURE Dart. No Flutter/Dio/GetIt (Clean Architecture).

class AuthSession {
  const AuthSession({
    required this.userId,
    this.email,
    this.status,
  });

  final String userId;
  final String? email;

  final String? status;
}

/// Non-enumerating: unknown email → 200 (don't reveal if email exists).
class RecoveryRequestResult {
  const RecoveryRequestResult({required this.expiresInSeconds});
  final int expiresInSeconds;
}

class RecoveryVerifyResult {
  const RecoveryVerifyResult({
    required this.resetToken,
    required this.expiresInSeconds,
  });
  final String resetToken;
  final int expiresInSeconds;
}

enum AuthFailure {
  network,
  invalidCredentials,
  emailCollision,
  invalidRecoveryCode,
  invalidToken,
  badRequest,
  unknown,
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.failure, [this.message]);
  final AuthFailure failure;
  final String? message;

  @override
  String toString() => 'AuthRepositoryException($failure, $message)';
}

abstract class AuthRepository {
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<RecoveryRequestResult> requestRecovery({required String email});

  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  });

  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  });
}
