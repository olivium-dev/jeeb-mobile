import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'app_lifecycle_gate.dart';
import 'polling_visibility.dart';

/// Periodic task: runs iff (started AND visible AND app-foreground).
/// Three INDEPENDENT latches: started, visible, foreground. A terminal stop() is STICKY—only explicit start() resurrects.
/// start() never fetches. Re-entrancy guarded: skips tick while previous future outstanding. Exceptions swallowed; schedule continues.
class LifecyclePoller implements PollingVisibility {
  LifecyclePoller({
    required Duration interval,
    required FutureOr<void> Function() onTick,
    AppLifecycleGate? gate,
    bool visible = true,
    bool tickOnResume = false,
    this.debugLabel = '',
  }) : _interval = interval,
       _onTick = onTick,
       _gate = gate ?? AppLifecycleGate.instance,
       _visible = visible,
       _tickOnResume = tickOnResume;

  final FutureOr<void> Function() _onTick;
  final AppLifecycleGate _gate;
  final bool _tickOnResume;

  final String debugLabel;

  Duration _interval;
  Timer? _timer;
  bool _started = false;
  bool _visible;
  bool _foreground = true;
  bool _subscribed = false;
  bool _disposed = false;
  bool _inFlight = false;
  int _tickGeneration = 0;
  int _tickCount = 0;

  Duration get interval => _interval;

  bool get isStarted => _started;

  bool get isVisible => _visible;

  bool get isForeground => _foreground;

  /// AC2 asserts isRunning==true (zero calls means battery bug intact).
  bool get isRunning => _timer != null;

  bool get isDisposed => _disposed;

  @visibleForTesting
  int get debugTickCount => _tickCount;

  void start() {
    if (_disposed || _started) return;
    _started = true;
    _subscribe();
    _sync(allowResumeTick: false);
  }

  /// STICKY: after stop(), neither setPollingVisible nor app resume re-arms. Use for permanent terminal stop.
  void stop() {
    if (!_started) return;
    _started = false;
    _clearInFlight();
    _sync();
    _unsubscribe();
  }

  @override
  void setPollingVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    _visible = visible;
    _sync();
  }

  /// Cancels current period, re-arms FULL fresh interval. Safe to call after fetch or after terminal stop().
  void restart() {
    if (_disposed || !_started) return;
    _clearInFlight();
    _timer?.cancel();
    _timer = null;
    _sync(allowResumeTick: false);
  }

  void setInterval(Duration value) {
    if (_disposed || value == _interval) return;
    _interval = value;
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _sync(allowResumeTick: false);
  }

  /// MUST be called from owner's close()/dispose().
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    _clearInFlight();
    _timer?.cancel();
    _timer = null;
    _unsubscribe();
  }

  void _subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    _foreground = _gate.isForeground;
    _gate.addForegroundListener(_onForegroundChanged);
  }

  void _unsubscribe() {
    if (!_subscribed) return;
    _subscribed = false;
    _gate.removeForegroundListener(_onForegroundChanged);
  }

  void _onForegroundChanged(bool isForeground) {
    if (_disposed) return;
    _foreground = isForeground;
    if (!isForeground) _clearInFlight();
    _sync();
  }

  void _sync({bool allowResumeTick = true}) {
    final shouldRun = _started && _visible && _foreground && !_disposed;
    final wasRunning = _timer != null;
    if (shouldRun == wasRunning) return;
    if (!shouldRun) {
      _timer!.cancel();
      _timer = null;
      return;
    }
    // Fresh FULL interval on every re-arm: resume with tickOnResume:false is exactly zero calls.
    _timer = Timer.periodic(_interval, (_) => _fire());
    if (_tickOnResume && allowResumeTick) _fire();
  }

  void _fire() {
    if (_disposed || _inFlight) return;
    _inFlight = true;
    final generation = ++_tickGeneration;
    _tickCount++;

    void release() {
      if (generation == _tickGeneration) _inFlight = false;
    }

    try {
      final Object? result = _onTick();
      if (result is Future) {
        unawaited(
          result
              .then<void>((_) {}, onError: (Object _, StackTrace _) {})
              .whenComplete(release),
        );
      } else {
        release();
      }
    } catch (_) {
      release();
    }
  }

  void _clearInFlight() {
    _tickGeneration++;
    _inFlight = false;
  }
}
