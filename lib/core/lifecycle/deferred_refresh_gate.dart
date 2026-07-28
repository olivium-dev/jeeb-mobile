import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'polling_visibility.dart';

/// A push-bus subscription that only READS while its surface is on screen, and
/// coalesces everything it missed into exactly ONE read when the surface comes
/// back.
///
/// ## The problem it exists to solve — read economics, not correctness
///
/// b02 wave D routed [PushRefreshSignals] by [RefreshTopic] and single-flighted
/// every subscriber, and both were necessary. Neither addresses the term that
/// dominated the remaining measurement: ONE `delivery` push still produced TEN
/// gateway reads on the customer phone, because the subscribers are all MOUNTED
/// AT ONCE and each one is individually correct.
///
/// With the customer sitting on the delivery-detail route, an `order` push woke:
///
/// | subscriber | on screen? | reads |
/// |---|---|---|
/// | `DeliveryDetailScreen._loadStatus` | YES | 1 — `GET /v1/deliveries/{id}` |
/// | `ChatDetailScreen._refreshSummary` (route BENEATH) | no | 3 — `/v1/deliveries/{id}` + `/v1/requests/{id}` + `/v1/offers` |
/// | `ClientHomeCubit.refresh` (shell tab, alive in the `IndexedStack`) | no | 7 — `/deliveries` + `/requests` ×2 + `/v1/offers` ×4 |
///
/// The device capture (`tools/STATE-PROVEN.md:181`) names the duplicate pattern
/// as the tell: `/v1/offers` ×4 and `/requests` ×2 for ONE event. Those exact
/// multiplicities are the client-home snapshot's own fan-out, measured
/// independently here against the real `DioClientHomeRepository` over a recording
/// adapter (`test/features/home_client/client_home_offscreen_push_budget_test.dart`).
///
/// A single-flight latch cannot help: these are three DIFFERENT subscribers, so
/// there is no shared in-flight read to collapse onto. A topic filter cannot help
/// either: all three genuinely render order state, so `{order}` is the correct
/// declaration for each. All but one of those reads repainted **pixels nobody
/// could see**.
///
/// ## Deferral, not suppression
///
/// Dropping an off-screen signal would be a staleness bug — the surface would
/// come back showing a pre-push snapshot with no error, which is invisible on
/// the device, in the journal and in a screenshot (the exact failure mode the
/// wave-D topic comment warns about). So this gate never drops: it records that
/// a refresh is OWED, and pays it once on the way back to visible.
///
///   * visible + signal      → refresh now.
///   * hidden + signal       → mark pending. No read.
///   * hidden + N signals    → still ONE pending. N collapses to one read, not N.
///   * hidden → visible with a pending → refresh once, clear the debt.
///   * hidden → visible with nothing pending → nothing. Becoming visible is not
///     itself an event; surfaces that want a read on re-entry already have their
///     own (`didPopNext`, `TabVisibility`), and firing here too would re-create
///     the duplicate fan-out this class removes.
///
/// The invariant a test can assert: **no user-visible state is ever stale, and
/// the number of reads is bounded by the number of times the surface is
/// LOOKED AT, not by the number of pushes the device received.**
///
/// ## Default is visible
///
/// [visible] defaults to `true`, so an adopter with no visibility driver behaves
/// EXACTLY as a bare `stream.listen(refresh)` did. That is the same safe
/// direction `resolvePushRefreshStream` chose for topics: an over-woken surface
/// costs a redundant read that a capture can see; an under-woken one shows stale
/// data with no error at all.
///
/// ## Not a debounce and not a poll
///
/// Nothing here is timed. There is no timer, no interval and no retry: the only
/// clock in the system is the user's own navigation. A pending refresh waits
/// indefinitely and is paid by a visibility change or by [dispose] (which pays
/// nothing — an unmounted surface has no pixels to be stale).
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

  /// Free-text label used only in diagnostics/assertion messages.
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

  /// Subscribe to the refresh bus. Idempotent and null-tolerant: a second call,
  /// or a `null` stream (a bare widget test with no DI), leaves the gate inert
  /// rather than throwing — the degradation every `resolvePushRefreshStream`
  /// call site already relies on.
  ///
  /// Separate from the constructor because [RequestFeedCubit] deliberately
  /// subscribes in `start()`, not at construction, so a cubit that is built and
  /// never started holds no live subscription.
  void bind(Stream<void>? signals) {
    if (_disposed || signals == null || _subscription != null) return;
    _subscription = signals.listen((_) => _onSignal());
  }

  void _onSignal() {
    if (_disposed) return;
    _signalCount++;
    if (!_visible) {
      // The debt is a BOOLEAN, not a counter: two pushes while hidden describe
      // one snapshot to catch up to, and the surface re-reads the whole
      // snapshot. Counting them would pay N reads for one repaint.
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

  /// Level-triggered and idempotent, per the [PollingVisibility] contract. A
  /// repeated value is a no-op, so the many rebuilds an adopter gets from
  /// `didChangeDependencies` never turn into reads.
  @override
  void setPollingVisible(bool visible) {
    if (_disposed || visible == _visible) return;
    _visible = visible;
    if (!visible || !_pending) return;
    // Coming back on screen owing a refresh: pay it once, now.
    _fire();
  }

  /// Whether the surface is currently considered on screen.
  @visibleForTesting
  bool get debugVisible => _visible;

  /// A refresh is owed: at least one signal arrived while hidden and has not
  /// been paid yet.
  @visibleForTesting
  bool get debugPending => _pending;

  /// Signals received from the bus, whatever was done with them.
  @visibleForTesting
  int get debugSignalCount => _signalCount;

  /// How many times a signal was DEFERRED rather than read (counted once per
  /// debt, so a hidden burst of five contributes one).
  @visibleForTesting
  int get debugDeferredCount => _deferredCount;

  /// How many times [_onRefresh] was actually invoked. The read budget.
  @visibleForTesting
  int get debugFiredCount => _firedCount;

  /// Cancel the bus subscription and abandon any pending debt. Deliberately
  /// does NOT fire: a disposed surface has no pixels that could be stale, and a
  /// refresh here would read on behalf of a widget that is gone.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pending = false;
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }
}
