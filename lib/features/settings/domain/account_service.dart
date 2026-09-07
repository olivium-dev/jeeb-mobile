enum AccountActionOutcome {
  success,
  networkError,
  alreadyPending,

  /// No session to act on — the caller must send the user back to sign-in.
  notSignedIn,

  /// The gateway answered, but with a 5xx: retrying may work, connectivity
  /// copy must not.
  serverError,
}

abstract class AccountService {
  Future<AccountActionOutcome> requestAccountDeletion();

  Future<AccountActionOutcome> signOut();
}
