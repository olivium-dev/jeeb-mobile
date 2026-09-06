import '../../../core/network/app_failure.dart';
import 'account_status.dart';

enum AccountStatusFailure {
  network,

  unauthorized,

  /// 403 — an authenticated read the gateway refuses; retrying cannot win.
  forbidden,

  /// 5xx — retryable, but the copy must never blame connectivity.
  serverError,

  unknown,
}

class AccountStatusRepositoryException implements Exception {
  const AccountStatusRepositoryException(
    this.failure, [
    this.message,
    this.appFailure,
  ]);
  final AccountStatusFailure failure;
  final String? message;

  /// The classified transport failure, so `failureCopy` keeps `Retry-After`,
  /// `problem.detail` and `offline` instead of a re-synthesised 500.
  final AppFailure? appFailure;

  @override
  String toString() =>
      'AccountStatusRepositoryException($failure${message == null ? '' : ': $message'})';
}

abstract class AccountStatusRepository {
  Future<AccountStatusInfo> fetchStatus();
}
