/// The narrow view of session state the router's redirect needs (FR-P0-3).
///
/// Kept as a tiny interface (not the full [SessionCubit]) so:
///   * the router redirect depends only on a boolean, not on bloc internals;
///   * tests can inject a scripted gate without a keystore;
///   * the default production-safe gate ([AlwaysAuthenticatedSessionGate]) can
///     be supplied when no real session is wired, preserving the prior router
///     behaviour for the existing call sites that predate this gate.
abstract class SessionGate {
  /// True only when session evaluation has run AND found no valid token.
  /// MUST be `false` during the cold-start `unknown` phase so the gate is a
  /// no-op until the keystore read resolves (no `/register` flash on launch).
  bool get isUnauthenticated;
}

/// Inert gate: never forces a redirect. Used as the router default so callers
/// that don't (yet) wire a [SessionCubit] keep the pre-FR-P0-3 behaviour, and
/// so widget tests that only exercise onboarding/biometric routing are
/// unaffected. Production wires the real [SessionCubit] instead.
class AlwaysAuthenticatedSessionGate implements SessionGate {
  const AlwaysAuthenticatedSessionGate();

  @override
  bool get isUnauthenticated => false;
}
