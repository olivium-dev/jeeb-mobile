/// Tri-state session status read by the router's first-run gate (FR-P0-3).
///
/// [unknown] is the cold-start value: the [AuthTokenStore] read is async, so
/// before the first [SessionCubit.refresh] resolves the gate must be a NO-OP
/// (exactly like the biometric gate's `unknown` phase) — otherwise we'd flash
/// `/register` for one frame on every launch while the keystore read is in
/// flight. Only [unauthenticated] forces the redirect to login.
enum SessionStatus {
  /// Token presence not yet evaluated (cold start). Gate is inert.
  unknown,

  /// A non-expired access token is present. User may reach Home.
  authenticated,

  /// No token, or the token is expired. User is forced to `/register`.
  unauthenticated,
}

/// Immutable session snapshot the router redirect reads.
class SessionState {
  const SessionState(this.status);

  /// Cold-start default — the gate does nothing until the first refresh.
  const SessionState.unknown() : status = SessionStatus.unknown;

  final SessionStatus status;

  /// True only when evaluation has run AND found no valid token. The router
  /// uses this (not `!authenticated`) so the [SessionStatus.unknown] cold-start
  /// state never triggers a redirect.
  bool get isUnauthenticated => status == SessionStatus.unauthenticated;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  bool get isKnown => status != SessionStatus.unknown;

  @override
  bool operator ==(Object other) =>
      other is SessionState && other.status == status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'SessionState(${status.name})';
}
