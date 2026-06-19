// PURE Dart. No Flutter / Dio / GetIt imports (Clean Architecture, 40_GUARDRAILS
// §1). The contract the W0 auth screens (JM-007/020/021/022) depend on.

/// A successful auth result that carries the minted session. The screens hand
/// this to the session layer; the data impl has already persisted the tokens to
/// the secure keystore by the time this is returned.
class AuthSession {
  const AuthSession({
    required this.userId,
    this.email,
    this.status,
  });

  /// The persisted user id (from `user.userId`). Splash session-routing
  /// (JM-006) reads this to `GET /users/:id` — NOT `/users/me`, which the mock
  /// `authStub` resolves to `user-client-001` regardless of token
  /// (42_GUARDRAILS_MOCK W-1 FLOOR).
  final String userId;
  final String? email;

  /// Account status from the auth bundle, if present (`active` on signup, D5).
  final String? status;
}

/// Result of a recovery-code request: the mock returns a `requestId` and a TTL.
/// Non-enumerating — an unknown email still returns 200 (W-1 FLOOR), so the UX
/// must not reveal whether the email exists.
class RecoveryRequestResult {
  const RecoveryRequestResult({required this.expiresInSeconds});
  final int expiresInSeconds;
}

/// Result of verifying a recovery code: mints a `resetToken` consumed by
/// set-password (recovery mode).
class RecoveryVerifyResult {
  const RecoveryVerifyResult({
    required this.resetToken,
    required this.expiresInSeconds,
  });
  final String resetToken;
  final int expiresInSeconds;
}

/// Typed failure surface for the auth funnel. The cubit maps each to localized
/// copy; the UI never sees a `DioException` (40_GUARDRAILS §4).
enum AuthFailure {
  /// Connection/timeout — retry.
  network,

  /// 401 `invalid_credentials` (login).
  invalidCredentials,

  /// 409 `email_collision` (signup) — the email is already registered, possibly
  /// via another method (D22). The sign-up screen routes this to the
  /// social-collision prompt (JM-019), it is NOT a terminal error.
  emailCollision,

  /// 401 `invalid_recovery_code` (recovery verify — wrong/expired code).
  invalidRecoveryCode,

  /// 401 `invalid_token` (set-password — reset token mismatch).
  invalidToken,

  /// 400 `bad_request` — malformed input.
  badRequest,

  /// Anything else.
  unknown,
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.failure, [this.message]);
  final AuthFailure failure;
  final String? message;

  @override
  String toString() => 'AuthRepositoryException($failure, $message)';
}

/// The W0 email-first auth funnel (CTO-D1). Phone-OTP sign-up verification stays
/// on the existing [OtpService] (the reused `/register` step, JM-009); social
/// stays on [SocialAuthService]. This repo owns email/password login + the
/// recovery + set-password legs.
abstract class AuthRepository {
  /// `POST /v1/auth/signup` — email-first sign-up (JM-008, CTO-D1). Find-or-create
  /// by email (W-1 FLOOR contract). 201 → persists tokens, returns the session
  /// (the account is `status:"active"`, but the phone is NOT yet verified — the
  /// caller still routes to phone-OTP per G8/D21). 409 `email_collision` →
  /// [AuthFailure.emailCollision] (D22 → social-collision prompt, JM-019). Email
  /// is NOT verified at this step (D21).
  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  });

  /// `POST /v1/auth/login` — email/password (JM-007).
  /// 200 → persists tokens, returns the session. 401 → [AuthFailure.invalidCredentials].
  Future<AuthSession> login({required String email, required String password});

  /// `POST /v1/auth/recovery/request` — non-enumerating (JM-020). Always 200.
  Future<RecoveryRequestResult> requestRecovery({required String email});

  /// `POST /v1/auth/recovery/verify` — 6-digit code (JM-021).
  /// 200 → returns a `resetToken`. 401 → [AuthFailure.invalidRecoveryCode].
  Future<RecoveryVerifyResult> verifyRecovery({
    required String email,
    required String code,
  });

  /// `POST /v1/auth/set-password` (JM-022). `resetToken` is required in
  /// recovery mode, optional for the in-app social mode (D90).
  /// 200 → persists tokens, returns the session. 401 → [AuthFailure.invalidToken].
  Future<AuthSession> setPassword({
    required String email,
    required String password,
    String? resetToken,
  });
}
