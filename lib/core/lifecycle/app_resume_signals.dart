import 'dart:async';

import 'package:flutter/widgets.dart';

import '../diagnostics/diag.dart';

/// The ONE app-wide "the user came back to the app — refetch" signal.
///
/// ## The defect this exists to remove (measured, b02 P0)
///
/// Before this class, EIGHT independent surfaces each did the same thing:
///
/// ```dart
/// void didChangeAppLifecycleState(AppLifecycleState state) {
///   if (state != AppLifecycleState.resumed) return;
///   ...refetch...
/// }
/// ```
///
/// Each one is individually correct and each was reviewed as such. Together
/// they are a multiplier: whatever number of `resumed` notifications the
/// platform delivers, the app issues THAT MANY TIMES the number of live
/// observers in gateway reads, with nothing bounding either factor.
///
/// On `RFCX306JSRT` (jeeber, s24), diag session
/// `2026-07-28T02-30-02-867Z-jeeber.jsonl`, seq 57..116: ONE two-second window
/// produced **60 gateway reads** — 20 identical rotations of
/// `GET /v1/users/me` + `GET /v1/jeebers/me/feed` + `GET /v1/deliveries/{id}`
/// at ~105 ms — terminated only by TWO 429s, after which the device read
/// nothing for 5 m 49 s. Those three paths are not a push fan-out. They are
/// exactly, and only, the three `resumed` observers that were alive on that
/// route:
///
///   1. `_JeebAppState.didChangeAppLifecycleState` → `RoleSync.sync()` →
///      `GET /v1/users/me`;
///   2. `FeedResumeRefetcher` → `RequestFeedCubit.refresh()` →
///      `GET /v1/jeebers/me/feed`;
///   3. `_ResumeRefresh` (active delivery) → `ActiveDeliveryCubit.refresh()` →
///      `GET /v1/deliveries/{id}`.
///
/// The attribution is not inferred from the code, it was measured: a single
/// HOME→foreground trip on the same installed binary (04:12:34Z, seq 123/124/
/// 125) produced those three paths, in that order, and nothing else. The storm
/// is that triple, twenty times.
///
/// ## Why single-flight was not enough
///
/// `ActiveDeliveryCubit.refresh` and `LiveTrackingCubit.refreshNow` ALREADY
/// carried in-flight latches, with doc comments correctly noting that `resumed`
/// "can fire MORE THAN ONCE for a single background→foreground trip". Those
/// latches did not fire once in the 60-read storm: each read completed in
/// ~20 ms and the next `resumed` arrived ~105 ms later, so no two calls ever
/// overlapped. A latch collapses CONCURRENT duplicates. It does nothing to a
/// SEQUENCE. The missing control is a floor on the rate, which is what this
/// class adds.
///
/// ## What it does
///
/// Two independent gates, both required to pass:
///
///   * **Genuine-resume gate.** A `resumed` notification only counts when the
///     app had actually LEFT the foreground since the last one — i.e. a
///     `paused`, `hidden` or `detached` was observed in between. A transient
///     focus loss (`inactive → resumed`: a heads-up notification, the shade,
///     a system permission dialog, a Samsung edge panel) is not the user
///     coming back and must refetch nothing. This is what makes a focus FLAP
///     free instead of quadratic.
///   * **Coalescing gate.** At most one signal per [minInterval], leading edge
///     first, with a TRAILING emission if anything was suppressed inside the
///     window. Trailing matters: dropping a suppressed resume outright is how
///     a screen silently keeps the pre-resume snapshot, which is invisible on
///     the device and in a screenshot. Coalescing delays the refetch; it never
///     cancels it.
///
/// Worst case after this change is ONE refetch round per subscriber per
/// [minInterval], regardless of what the platform does — 3 reads / 2 s on the
/// measured route, against the measured 30 reads / s.
///
/// ## Diagnostics
///
/// Every decision is journalled (`app_resume` / `app_resume_suppressed`), so a
/// future recurrence is one `grep` away instead of an archaeology exercise over
/// raw API rows. `Diag` is a no-op in release, so this costs nothing shipped.
class AppResumeSignals with WidgetsBindingObserver {
  AppResumeSignals({
    this.minInterval = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Floor between two emissions. Chosen against what it replaced, not
  /// arbitrarily: the surfaces downstream of this bus had 5 s–60 s wall-clock
  /// polls before the polling→push conversion, so a 2 s floor is still far more
  /// responsive than the cadence it retired while capping the measured storm at
  /// 1/40th of its observed rate.
  final Duration minInterval;

  final DateTime Function() _now;

  /// SYNCHRONOUS on purpose. This bus replaces eight direct
  /// `didChangeAppLifecycleState` overrides, which the binding invoked
  /// synchronously; every subscriber (and every test's pump budget) was written
  /// against that timing. An async broadcast delivers one microtask later,
  /// which lands a subscriber's `addPostFrameCallback` AFTER the current frame's
  /// post-frame phase — so the refetch silently slips a whole frame, or in a
  /// widget test never runs at all. Verified: with an async controller the
  /// active-delivery resume refetch fired only during teardown.
  final StreamController<void> _controller =
      StreamController<void>.broadcast(sync: true);

  /// True once a background-class state has been observed since the last
  /// accepted resume. Seeded `false`: the app is already `resumed` at start-up
  /// and no notification fires for that, so the cold-start reads are owned by
  /// `initState` and must not be duplicated here.
  bool _sawBackground = false;

  DateTime? _lastEmit;
  Timer? _trailing;
  bool _installed = false;

  /// Number of accepted signals — test/diagnostic seam.
  int emitCount = 0;

  /// Number of `resumed` notifications rejected by either gate — test seam, and
  /// the number that makes a flap visible.
  int suppressedCount = 0;

  /// Subscribe to accepted resumes. Broadcast: every surface gets every signal.
  Stream<void> get stream => _controller.stream;

  /// Register with the widgets binding. Idempotent, so a second call from a
  /// hot-restart or a test bootstrap is harmless.
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
        // Deliberately NOT background. `inactive` is a focus loss the app can
        // be driven through many times a second without ever leaving the
        // screen; treating it as a trip is the whole storm.
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

    // Inside the window: coalesce. One trailing timer at most — a burst of
    // twenty collapses onto the single already-scheduled emission.
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

  /// Drive an accepted resume without a platform notification. Test-only seam —
  /// production code must go through the real lifecycle.
  @visibleForTesting
  void debugEmit() => _emit(_now(), 'debug');

  /// Mark the app as having been backgrounded without a platform notification.
  /// Test seam for "the app really did take a trip".
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

  // -------------------------------------------------------------------------
  // Ambient instance
  //
  // A GetIt registration would be the house style, but this bus is consumed by
  // `State.initState` on screens that are pumped in bare widget tests with no
  // DI graph at all, and the "resolve it or degrade to null" dance is exactly
  // how one surface silently keeps its own observer while its twin moves to the
  // shared one — the failure `resolvePushRefreshStream` was written to prevent,
  // one layer down. An ambient singleton has no null branch to get wrong.
  // -------------------------------------------------------------------------

  static AppResumeSignals? _instance;

  /// The process-wide instance, created (and installed on the binding) on first
  /// use.
  static AppResumeSignals get instance {
    final existing = _instance;
    if (existing != null) return existing;
    final created = AppResumeSignals()..install();
    _instance = created;
    return created;
  }

  /// Replace the ambient instance. Test-only.
  @visibleForTesting
  static set instance(AppResumeSignals value) => _instance = value;

  /// Drop the ambient instance so the next [instance] read rebuilds it. Test
  /// isolation seam — a leaked observer across tests makes the coalescing
  /// window bleed between cases.
  @visibleForTesting
  static Future<void> debugReset() async {
    final existing = _instance;
    _instance = null;
    if (existing != null) await existing.dispose();
  }
}

/// Consumes [AppResumeSignals] from a [State], replacing the hand-rolled
/// `WidgetsBindingObserver` + `if (state == resumed)` pair that every refetching
/// screen used to carry.
///
/// Mix it in and implement [onAppResumed]. The observer plumbing, the
/// genuine-resume filter and the coalescing all live in the bus, so a new
/// screen cannot re-introduce the storm by forgetting a latch: there is no
/// per-screen lifecycle code left to get wrong.
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

  /// Called at most once per [AppResumeSignals.minInterval], and only after the
  /// app genuinely left and re-entered the foreground.
  void onAppResumed();
}
