import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'polling_visibility.dart';

/// Defers off-screen pushes into ONE read on return. Trap: never drops signals.
class DeferredRefreshGate implements PollingVisibility {
  DeferredRefreshGate({
    required FutureOr<void> Function() onRefresh,
    Stream<void>? signals,
    bool visible = true,
    this.debugLabel = '',
  }) : _onRefresh = onRefresh,
       _visible = visible {
    bind(signals);
  }

  final FutureOr<void> Function() _onRefresh;

  final String debugLabel;

  // Cancelled in [dispose]. The analyzer's `cancel_subscriptions` rule cannot
  // follow a subscription stored on a field and cancelled from another method.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _subscription;
  bool _visible;
  bool _pending = false;
  bool _disposed = false;
  int _signalCount = 0;
  int _deferredCount = 0;
  int _firedCount = 0;

  /// Idempotent, null-tolerant; separate from constructor for deferred subscribe.
  void bind(Stream<void>? signals) {
    if (_disposed || signals == null || _subscription != null) return;
    _subscription = signals.listen((_) => _onSignal());
  }

  /// Routes through gate to preserve read economics on resume.
  void signal() => _onSignal();

  void _onSignal() {
    if (_disposed) return;
    _signalCount++;
    if (!_visible) {
      // Debt is boolean, not counter.
      if (!_pending) _deferredCount++;
      _pending = true;
      return;
    }
    _fire();
  }

  void _fire() {
    _firedCount++;
    _pending = false;
    unawaited(Future<void>.sync(_onRefresh));
  }

  /// Idempotent per PollingVisibility contract.
  @override
  void setPollingVisible(bool visible) {
    if (_disposed || visible == _visible) return;
    _visible = visible;
    if (!visible || !_pending) return;
    _fire();
  }

  @visibleForTesting
  bool get debugVisible => _visible;

  @visibleForTesting
  bool get debugPending => _pending;

  @visibleForTesting
  int get debugSignalCount => _signalCount;

  @visibleForTesting
  int get debugDeferredCount => _deferredCount;

  @visibleForTesting
  int get debugFiredCount => _firedCount;

  /// Does NOT fire; disposed surface has no pixels to be stale.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending = false;
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }
}
