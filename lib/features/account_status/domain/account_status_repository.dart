import 'account_status.dart';

/// Typed failures the cubit maps to localized copy (40_GUARDRAILS_ARCH §3/§4).
/// The UI never sees a `DioException`.
enum AccountStatusFailure {
  /// Connection / timeout — retryable.
  network,

  /// Token rejected (401). The session is, by gate contract, authenticated, so
  /// a 401 here is a transport/session edge — retryable, surfaced as an error.
  unauthorized,

  /// Anything else (5xx, parse, etc.).
  unknown,
}

class AccountStatusRepositoryException implements Exception {
  const AccountStatusRepositoryException(this.failure, [this.message]);
  final AccountStatusFailure failure;
  final String? message;

  @override
  String toString() =>
      'AccountStatusRepositoryException($failure${message == null ? '' : ': $message'})';
}

/// Reads the blocked-account status the screen renders (JM-066, D5). The
/// abstraction lets the cubit stay pure of Dio and lets tests/DI swap impls.
///
/// Mock: `GET /users/me` (U1 — surfaces `status`, 42_GUARDRAILS_MOCK W-1 FLOOR).
abstract class AccountStatusRepository {
  Future<AccountStatusInfo> fetchStatus();
}
