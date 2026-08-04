import 'dart:async';

import 'package:flutter/widgets.dart';

import '../diagnostics/diag.dart';

/// Coalesces background→foreground resumes (prevents 60 reads/2s storm → 3 reads/2s).
class AppResumeSignals with WidgetsBindingObserver {
  AppResumeSignals({
    this.minInterval = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration minInterval;

  final DateTime Function() _now;

  /// SYNCHRONOUS on purpose: WidgetsBinding invokes sync. Async fires AFTER post-phase → refetch slips frame.
  /// TRAP: async caused active-delivery resume to fire only during teardown in tests.
  final StreamController<void> _controller =
      StreamController<void>.broadcast(sync: true);

  bool _sawBackground = false;

  DateTime? _lastEmit;
  Timer? _trailing;
  bool _installed = false;

  int emitCount = 0;
  int suppressedCount = 0;

  Stream<void> get stream => _controller.stream;

  void install() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _sawBackground = true;
      case AppLifecycleState.inactive:
        // NOT background: transient focus loss (permission dialog). Treats as resume = storm.
        break;
      case AppLifecycleState.resumed:
        _onResumed();
    }
  }

  void _onResumed() {
    if (!_sawBackground) {
      suppressedCount++;
      Diag.event('app_resume_suppressed', <String, Object?>{
        'reason': 'focus_flap',
        'count': suppressedCount,
      });
      return;
    }
    _sawBackground = false;

    final now = _now();
    final last = _lastEmit;
    if (last == null || now.difference(last) >= minInterval) {
      _emit(now, 'leading');
      return;
    }

    // Coalesce: one trailing timer max.
    suppressedCount++;
    Diag.event('app_resume_suppressed', <String, Object?>{
      'reason': 'coalesced',
      'count': suppressedCount,
    });
    if (_trailing != null) return;
    final wait = minInterval - now.difference(last);
    _trailing = Timer(wait, () {
      _trailing = null;
      _emit(_now(), 'trailing');
    });
  }

  void _emit(DateTime at, String edge) {
    if (_controller.isClosed) return;
    _lastEmit = at;
    emitCount++;
    Diag.event('app_resume', <String, Object?>{
      'edge': edge,
      'count': emitCount,
    });
    _controller.add(null);
  }

  @visibleForTesting
  void debugEmit() => _emit(_now(), 'debug');

  @visibleForTesting
  void debugMarkBackgrounded() => _sawBackground = true;

  Future<void> dispose() async {
    _trailing?.cancel();
    _trailing = null;
    if (_installed) {
      WidgetsBinding.instance.removeObserver(this);
      _installed = false;
    }
    await _controller.close();
  }

  /// TRAP: ambient singleton (not GetIt). GetIt's fallback can let one surface silently
  /// keep its own observer while twin moves to shared one.
  static AppResumeSignals? _instance;

  static AppResumeSignals get instance {
    final existing = _instance;
    if (existing != null) return existing;
    final created = AppResumeSignals()..install();
    _instance = created;
    return created;
  }

  @visibleForTesting
  static set instance(AppResumeSignals value) => _instance = value;

  /// Drop ambient instance. Test isolation: leaked observer across tests bleeds coalescing window.
  @visibleForTesting
  static Future<void> debugReset() async {
    final existing = _instance;
    _instance = null;
    if (existing != null) await existing.dispose();
  }
}

/// Mixin: screen refetch on resume (replaces hand-rolled observer on each screen).
/// Observer plumbing, genuine-resume filter, coalescing live in bus.
mixin ResumeRefetchMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<void>? _resumeSub;

  @override
  void initState() {
    super.initState();
    _resumeSub = AppResumeSignals.instance.stream.listen((_) {
      if (mounted) onAppResumed();
    });
  }

  @override
  void dispose() {
    _resumeSub?.cancel();
    _resumeSub = null;
    super.dispose();
  }

  /// Called ≤1x per [AppResumeSignals.minInterval], only after genuine background→foreground trip.
  void onAppResumed();
}
