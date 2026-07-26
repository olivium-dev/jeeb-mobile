import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'app_lifecycle_gate.dart';
import 'polling_visibility.dart';

/// A periodic task that runs iff (started AND visible AND app-foreground).
///
/// ## Three INDEPENDENT latches, deliberately
///  * `started`    — the adopter's own intent.        [start] / [stop]
///  * `visible`    — the surface is on screen.        [setPollingVisible]
///  * `foreground` — app-wide, automatic.             [AppLifecycleGate]
///
/// They are independent so that a **terminal [stop] is STICKY**: no visibility
/// change and no foreground change can resurrect a stopped poller. Only an
/// explicit [start] can. This is why the gate widget drives
/// [setPollingVisible] and NOT [start]/[stop].
///
/// ## [start] never fetches
/// Arming the schedule performs no immediate fetch. Initial load, resume
/// refetch, push refetch and visibility refetch stay explicit feature
/// concerns — two surfaces already refetch on resume on their own
/// (`feed_resume_refetcher.dart:67-70`, `client_home_screen.dart:118-124`),
/// so a fetching [start] would double-fetch.
///
/// ## Re-entrancy
/// A tick is skipped while the previous tick's future is outstanding. The
/// latch is cleared by [stop], [dispose] and by backgrounding, and the
/// completion callback is generation-guarded, so a hung request can never
/// wedge the poller permanently "alive but never fetching".
///
/// ## Error policy
/// An exception or a rejected future from `onTick` is swallowed and the
/// schedule continues. A poller that dies on the first 500 is worse than one
/// that retries.
///
/// ## Determinism
/// Uses `Timer.periodic` from the ambient zone, so `package:fake_async` and
/// `flutter_test` both virtualise it with no injection seam.
///
/// ## No root install required (R8)
/// With nothing installed, [AppLifecycleGate.instance] forwards to
/// [AlwaysForegroundAppLifecycleGate]: `isForeground` is `true` forever and a
/// started, visible poller ticks exactly as an unconditional `Timer.periodic`
/// does today. No [WidgetsBinding] is touched on that path, so this class
/// works in a plain `test()` inside `FakeAsync().run()`.
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

  /// Free-text label used only in assertion messages.
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

  /// The current cadence. Changed with [setInterval].
  Duration get interval => _interval;

  /// Polling intent, regardless of visibility or foreground state.
  bool get isStarted => _started;

  /// The surface is on screen, as last reported by [setPollingVisible].
  bool get isVisible => _visible;

  /// The app was foreground at the last observed transition.
  bool get isForeground => _foreground;

  /// A `Timer` is actually scheduled. **This is the property AC2 asserts on**
  /// — a "zero calls" assertion with `isRunning == true` means the battery bug
  /// is intact.
  bool get isRunning => _timer != null;

  bool get isDisposed => _disposed;

  @visibleForTesting
  int get debugTickCount => _tickCount;

  /// Declare polling intent. Idempotent — a second call never re-schedules and
  /// never fetches.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    _subscribe();
    _sync(allowResumeTick: false);
  }

  /// Withdraw intent and cancel any scheduled timer. Idempotent, safe before
  /// [start], safe after [dispose].
  ///
  /// **STICKY:** after [stop], neither [setPollingVisible] nor an app resume
  /// re-arms the poller. Use this to express a permanent terminal stop.
  void stop() {
    if (!_started) return;
    _started = false;
    _clearInFlight();
    _sync();
    _unsubscribe();
  }

  /// Report surface visibility. Idempotent. Never re-arms a stopped poller.
  @override
  void setPollingVisible(bool visible) {
    if (_disposed || _visible == visible) return;
    _visible = visible;
    _sync();
  }

  /// Cancel the current period and re-arm a FULL fresh interval from now.
  /// No-op when not started (so it is safe to call unconditionally after a
  /// fetch, and safe after a terminal [stop]).
  void restart() {
    if (_disposed || !_started) return;
    _clearInFlight();
    _timer?.cancel();
    _timer = null;
    _sync(allowResumeTick: false);
  }

  /// Change the cadence. Takes effect immediately if a timer is scheduled
  /// (re-armed from now), otherwise on the next arm. Idempotent.
  void setInterval(Duration value) {
    if (_disposed || value == _interval) return;
    _interval = value;
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _sync(allowResumeTick: false);
  }

  /// Cancel permanently and detach from the gate. Idempotent. MUST be called
  /// from the owner's `close()`/`dispose()`.
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
    // A fresh FULL interval on every (re)arm. Resume never inherits a
    // partially elapsed period, so "resume with tickOnResume:false" is
    // exactly zero calls (guardrail T3, no resume stampede).
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
