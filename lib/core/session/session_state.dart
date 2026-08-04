enum SessionStatus {

  unknown,

  authenticated,

  unauthenticated,
}

class SessionState {
  const SessionState(this.status);

  const SessionState.unknown() : status = SessionStatus.unknown;

  final SessionStatus status;

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
