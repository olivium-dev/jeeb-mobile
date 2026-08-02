abstract class SessionGate {

  bool get isUnauthenticated;
}

class AlwaysAuthenticatedSessionGate implements SessionGate {
  const AlwaysAuthenticatedSessionGate();

  @override
  bool get isUnauthenticated => false;
}
