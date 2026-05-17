/// Outcomes for the destructive account actions surfaced from the settings
/// list (T-mobile-031): delete-account and sign-out.
enum AccountActionOutcome { success, networkError, alreadyPending }

/// Seam over the jeeb-gateway account endpoints.
///
/// The settings cubit talks to this interface, not directly to a Dio client,
/// so the screen layer can be exercised with a scripted fake in widget tests
/// and so the real implementation can be swapped in once the gateway
/// endpoints land without touching the cubit.
abstract class AccountService {
  /// Queue the signed-in user's account for deletion. Side-effect-free if
  /// the gateway reports an existing pending request — the cubit surfaces
  /// the `alreadyPending` outcome to the UI to avoid double-firing.
  Future<AccountActionOutcome> requestAccountDeletion();

  /// Drop the active session (clears tokens, profile cache, etc.). The
  /// cubit handles cache-clearing locally; this hook lets the gateway
  /// invalidate refresh tokens.
  Future<AccountActionOutcome> signOut();
}

/// Default no-network implementation used during MVP and in widget tests
/// that don't care about the network outcome. Always returns success.
class FakeAccountService implements AccountService {
  const FakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async {
    return AccountActionOutcome.success;
  }

  @override
  Future<AccountActionOutcome> signOut() async {
    return AccountActionOutcome.success;
  }
}
