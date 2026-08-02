import 'account_status.dart';

enum AccountStatusFailure {
  network,

  unauthorized,

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

abstract class AccountStatusRepository {
  Future<AccountStatusInfo> fetchStatus();
}
