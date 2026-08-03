import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

class StubAccountStatusRepository implements AccountStatusRepository {
  const StubAccountStatusRepository();

  @override
  Future<AccountStatusInfo> fetchStatus() async =>
      const AccountStatusInfo(value: AccountStatusValue.suspended);
}
