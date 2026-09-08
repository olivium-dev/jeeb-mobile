import 'dart:async';

/// Why the session ended, so the login surface can explain itself (NET-18).
enum AuthLossReason {
  /// The gateway rejected the refresh: the session really is over.
  sessionExpired,

  /// The keystore could not be read, so no bearer can be attached (NET-02).
  storeUnavailable,

  /// The user asked to sign out.
  signedOut,
}

/// Process-local signal emitted after an unrecoverable HTTP 401 clears tokens.
final class AuthLossSignals {
  AuthLossSignals._();

  static final AuthLossSignals instance = AuthLossSignals._();

  final StreamController<AuthLossReason> _controller =
      StreamController<AuthLossReason>.broadcast(sync: true);

  Stream<AuthLossReason> get stream => _controller.stream;

  /// Last reason signalled, for a surface that mounts after the signal.
  AuthLossReason? get lastReason => _lastReason;

  AuthLossReason? _lastReason;

  void signal({AuthLossReason reason = AuthLossReason.sessionExpired}) {
    _lastReason = reason;
    _controller.add(reason);
  }

  void clearReason() => _lastReason = null;
}
