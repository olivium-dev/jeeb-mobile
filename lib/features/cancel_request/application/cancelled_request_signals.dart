import 'dart:async';

import '../../../core/di/injection_container.dart';

/// Ids of requests whose DELETE already landed. The sheet that cancels lives on
/// the waiting route; the list that must shrink lives on another one.
class CancelledRequestSignals {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  void signalCancelled(String requestId) {
    if (_controller.isClosed || requestId.isEmpty) return;
    _controller.add(requestId);
  }

  Future<void> dispose() => _controller.close();
}

/// The registered bus (see `cancel_request_di.dart`), or a harness-local one so
/// a bare widget test never mutates the locator.
CancelledRequestSignals resolveCancelledRequestSignals() =>
    sl.isRegistered<CancelledRequestSignals>()
        ? sl<CancelledRequestSignals>()
        : _unregisteredFallback ??= CancelledRequestSignals();

CancelledRequestSignals? _unregisteredFallback;
