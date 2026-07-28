import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/diag.dart';

/// Minimum wall-clock gap between two accepted reconnect signals.
///
/// Mirrors [AppResumeSignals.minInterval] (2 s) for the same reason: the OS can
/// drive a transport flap many times a second (Android reports WiFi and mobile
/// as separate transports, so a handover emits a real offline→online edge per
/// leg), and a bus with no floor hands every consumer that burst verbatim.
const Duration kNetworkReachabilityMinInterval = Duration(seconds: 2);

/// The ONE app-wide "the device's network just came back" signal.
///
/// ## The defect this exists to remove (falsified claim, b02)
///
/// `chat_detail_screen.dart` renders [OmdsErrorStatePage] when a conversation
/// resolution COULD NOT FIND OUT (network down / 5xx / timeout) and re-attempts
/// on `kChatResolutionRetryBackoff` (2 s → 5 s → 15 s → 30 s). That backoff was
/// merged with the claim that the screen "SELF-HEALS on reconnect".
///
/// **It did not.** An independent tester falsified it two ways:
///
///   1. **Source fact.** There was no connectivity subscriber anywhere in
///      `lib/` — zero hits for `connectivity_plus`, `onConnectivityChanged`,
///      `ConnectivityResult`, `checkConnectivity`, `InternetAddress.lookup`,
///      `internet_connection_checker` and `network_info_plus`, and no such
///      package in `pubspec.yaml`. Nothing in the app was listening for the
///      network coming back.
///   2. **Cross-run tick-spacing identity.** The observed 0.46 s heal latency
///      tracked the BACKOFF TIMER'S PHASE, not the reconnect instant. Re-run
///      with an independently-phased backoff, the latency followed the timer
///      again. The heal was a coincidence of `mount_time + k*interval` landing
///      shortly after the network returned.
///
/// The screen's own doc comment argued the subscriber was unnecessary — "the
/// retry IS the connectivity probe". That is true of the probe and false of the
/// TIMING: a retry only probes when its timer fires, so a reconnect one second
/// after a 30 s step began is invisible for 29 s. This bus supplies the missing
/// EVENT; the backoff stays exactly as it was, as the fallback.
///
/// ## What it does
///
/// Consumes a `Stream<bool>` of "the OS reports a usable network" and
/// re-emits ONLY the **offline → online edge**. Three filters, in order:
///
///   * **Edge filter.** Emits iff the previous observation was `false` and the
///     new one is `true`. The FIRST observation is a baseline and never emits —
///     we cannot claim a reconnect happened if we never saw the disconnect.
///     Going offline emits nothing, and online→online is deduped.
///   * **Throttle.** At most one signal per [minInterval], leading edge, by
///     wall-clock comparison.
///   * **Liveness.** A source that throws is swallowed; the bus then simply
///     never emits and every consumer is exactly as well off as before this
///     class existed.
///
/// ## Why suppressed events are DROPPED, not deferred
///
/// [AppResumeSignals] coalesces with a TRAILING timer, because dropping a
/// suppressed resume there leaves a screen holding a stale snapshot with
/// nothing to correct it. This bus deliberately has no trailing edge, and the
/// reason is structural rather than a shortcut: **every consumer of this bus is
/// required to keep its own bounded backoff as the fallback, so the backoff IS
/// the trailing edge.** A dropped reconnect costs at most one backoff step; it
/// can never strand a surface. That is also what keeps this file free of any
/// `Timer` — a connectivity LISTENER is event-driven, and an armed-poll census
/// that cannot tell it apart from a poll would be measuring the wrong thing.
///
/// ## Why "the OS says online" is not "the gateway is reachable"
///
/// It is not, and this class does not claim otherwise. A phone can hold a
/// perfect WiFi association to a gateway it cannot reach — JEBV4-337's
/// half-open pooled connections looked exactly like that, and the tester
/// measured 3.75 s between `svc wifi enable` and a usable network. So a signal
/// from this bus is a REASON TO TRY, never evidence of success: a consumer that
/// attempts and fails must fall back to its backoff, not retry hot.
class NetworkReachabilitySignals {
  NetworkReachabilitySignals({
    this.minInterval = kNetworkReachabilityMinInterval,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Floor between two accepted emissions. See
  /// [kNetworkReachabilityMinInterval].
  final Duration minInterval;

  final DateTime Function() _now;

  /// SYNCHRONOUS, for the same reason [AppResumeSignals] is: subscribers call
  /// back into `State` methods whose timing (and whose widget-test pump budget)
  /// was written against a synchronous delivery. An async broadcast lands one
  /// microtask later, which in a widget test can slip past the pump the
  /// assertion is written against.
  final StreamController<void> _controller =
      StreamController<void>.broadcast(sync: true);

  StreamSubscription<bool>? _sourceSub;

  /// Last observed OS reachability. `null` until the first observation, which
  /// is the baseline and never emits.
  bool? _online;

  DateTime? _lastEmit;

  /// Accepted reconnect signals — test/diagnostic seam.
  int emitCount = 0;

  /// Edges rejected by the throttle — test seam, and the number that makes a
  /// transport flap visible instead of silent.
  int suppressedCount = 0;

  /// Subscribe to accepted reconnects. Broadcast: every surface gets every
  /// signal.
  Stream<void> get stream => _controller.stream;

  /// Last observed reachability, `null` before the first observation. Read-only
  /// diagnostic seam — a consumer must react to [stream], never poll this.
  bool? get debugOnline => _online;

  /// Bind the OS source. Idempotent in the sense that a second call replaces
  /// the first subscription rather than stacking one; the observed state is
  /// deliberately NOT reset, so a rebind cannot manufacture a phantom edge.
  ///
  /// [seed] is a one-shot read of the CURRENT state (e.g.
  /// `Connectivity().checkConnectivity()`), used to establish the baseline so a
  /// cold start that is ALREADY offline still produces a real offline→online
  /// edge when the network returns. That is the exact scenario the falsified
  /// claim was measured in, and without the seed it would depend on the
  /// platform choosing to replay its current state on subscribe. It is one
  /// platform-channel call at startup, not a network read and not a cadence.
  void bindSource(Stream<bool> source, {Future<bool>? seed}) {
    _sourceSub?.cancel();
    _sourceSub = source.listen(
      _observe,
      // A source that errors must degrade to silence, never crash the app or
      // tear down the subscription: the consumer's backoff is still armed and
      // still correct, so "no events" is precisely the pre-existing behaviour.
      onError: (Object error) {
        Diag.event('network_reachability_source_error', <String, Object?>{
          'error': '$error',
        });
      },
      cancelOnError: false,
    );
    if (seed != null) unawaited(_applySeed(seed));
  }

  Future<void> _applySeed(Future<bool> seed) async {
    try {
      final online = await seed;
      // Only seed if nothing real has been observed yet — a live event that
      // beat the seed is newer and must win.
      _online ??= online;
    } catch (error) {
      // An unavailable platform channel leaves the baseline unknown, which is
      // the honest state: the first real event becomes the baseline instead.
      Diag.event('network_reachability_seed_failed', <String, Object?>{
        'error': '$error',
      });
    }
  }

  void _observe(bool online) {
    final previous = _online;
    _online = online;
    // The EDGE filter. `previous == null` is the baseline observation and
    // `previous == true` is a dedupe; neither is a reconnect.
    if (previous != false || !online) return;

    final now = _now();
    final last = _lastEmit;
    if (last != null && now.difference(last) < minInterval) {
      suppressedCount++;
      Diag.event('network_reachable_suppressed', <String, Object?>{
        'reason': 'throttled',
        'count': suppressedCount,
      });
      return;
    }
    _emit(now);
  }

  void _emit(DateTime at) {
    if (_controller.isClosed) return;
    _lastEmit = at;
    emitCount++;
    Diag.event('network_reachable', <String, Object?>{'count': emitCount});
    _controller.add(null);
  }

  /// Drive an OS observation without a platform channel. Test-only seam —
  /// production code must go through [bindSource].
  @visibleForTesting
  void debugObserve({required bool online}) => _observe(online);

  Future<void> dispose() async {
    await _sourceSub?.cancel();
    _sourceSub = null;
    await _controller.close();
  }

  // -------------------------------------------------------------------------
  // Ambient instance
  //
  // Same rationale as [AppResumeSignals]: this bus is consumed by
  // `State.initState` on screens that are pumped in bare widget tests with no
  // DI graph at all, and the "resolve it from GetIt or degrade to null" dance
  // is exactly how one surface silently keeps listening to nothing while its
  // twin moves to the shared bus. An ambient singleton has no null branch to
  // get wrong.
  // -------------------------------------------------------------------------

  static NetworkReachabilitySignals? _instance;

  /// The process-wide instance, created on first use. Created UNBOUND: with no
  /// source it never emits, which is what makes it safe to read from a widget
  /// test that has no plugin registered.
  static NetworkReachabilitySignals get instance =>
      _instance ??= NetworkReachabilitySignals();

  /// Replace the ambient instance. Test-only.
  @visibleForTesting
  static set instance(NetworkReachabilitySignals value) => _instance = value;

  /// Drop the ambient instance so the next [instance] read rebuilds it. Test
  /// isolation seam — a leaked bus across tests makes the throttle window and
  /// the observed baseline bleed between cases.
  @visibleForTesting
  static Future<void> debugReset() async {
    final existing = _instance;
    _instance = null;
    if (existing != null) await existing.dispose();
  }
}
