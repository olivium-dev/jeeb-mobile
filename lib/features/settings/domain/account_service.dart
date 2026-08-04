enum AccountActionOutcome { success, networkError, alreadyPending }

abstract class AccountService {
  Future<AccountActionOutcome> requestAccountDeletion();

  Future<AccountActionOutcome> signOut();
}
