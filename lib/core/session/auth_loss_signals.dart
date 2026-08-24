import 'dart:async';

/// Process-local signal emitted after an unrecoverable HTTP 401 clears tokens.
final class AuthLossSignals {
  AuthLossSignals._();

  static final AuthLossSignals instance = AuthLossSignals._();

  final StreamController<void> _controller = StreamController<void>.broadcast(
    sync: true,
  );

  Stream<void> get stream => _controller.stream;

  void signal() => _controller.add(null);
}
