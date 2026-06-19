/// The narrow view of account-status the router's redirect needs (JM-066, D5).
///
/// Kept as a tiny interface (not a full cubit) for the same reasons as
/// [SessionGate] (see `session_gate.dart`):
///   * the router redirect depends only on a boolean, not on bloc internals;
///   * tests can inject a scripted gate without a network round-trip;
///   * the default production-safe gate ([AlwaysActiveAccountStatusGate]) is
///     supplied when no real status source is wired, preserving the prior
///     router behaviour (account-status gate is a NO-OP) for every existing
///     call site that predates this gate.
///
/// W0-INT lands ONLY the redirect-gate predicate (this interface + the router
/// branch). The concrete gate — which `GET /users/:id` by the persisted
/// `userId` (NOT `/users/me`, which the mock `authStub` resolves to
/// `user-client-001` regardless of token; 42_GUARDRAILS_MOCK W-1 FLOOR) and
/// classifies `status ∈ {suspended, locked}` — is the JM-006 / JM-066 engineer's
/// to write (it becomes a `Cubit` added to the router's `refreshListenable`,
/// exactly like [SessionCubit]).
abstract class AccountStatusGate {
  /// True only when status evaluation has run AND found the account blocked
  /// (`status ∈ {suspended, locked}`, D5). MUST be `false` during any
  /// not-yet-evaluated / cold-start phase so the gate is a no-op until the
  /// status read resolves (no `/account-status` flash on launch), and `false`
  /// for an active account so all tabs remain reachable.
  bool get isBlocked;
}

/// Inert gate: never forces the account-status redirect. Used as the router
/// default so callers (and tests) that don't wire a real status source keep the
/// pre-JM-066 behaviour. Production wires the real status cubit (JM-006/066).
class AlwaysActiveAccountStatusGate implements AccountStatusGate {
  const AlwaysActiveAccountStatusGate();

  @override
  bool get isBlocked => false;
}
