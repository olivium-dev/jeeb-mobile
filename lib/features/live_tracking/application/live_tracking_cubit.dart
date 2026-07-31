import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'live_tracking_state.dart';

/// b02 wave C — N7. This cubit used to run ONE 5s poll serving TWO data needs.
/// Splitting them is the whole change, because they are not the same shape and
/// only one of them is a push:
///
///  * **Status transitions are EVENTS.** Discrete and rare. The gateway's
///    `type=delivery` push carries them and reaches the CUSTOMER —
///    `NotifyOtherPartyAsync` puts `req.ClientId` on the recipient list
///    (`Controllers/DeliveriesController.cs:1296-1300`) and
///    `Notifications/DeliveryStatusPushNotifier.cs:211` stamps the
///    `type=delivery` + snake_case `delivery_id` pair the mobile handler's
///    `orderish` id guard requires. → [refreshSignals]. Retires
///    `GET /v1/deliveries/{id}`.
///  * **Courier position** rides `GET /deliveries/{id}/tracking` — a one-shot
///    JSON snapshot of the newest fix the jeeber's uploader wrote, read on the
///    SAME events as the status. → [LivePositionSource].
///
/// ## Why the position stream is gone (P0, 2026-07-31)
///
/// The bullet above used to read "*Courier position is a STREAM*", served by
/// `SseLivePositionStream` over `GET /v1/geo/jeeb/stream/{id}`. **That route no
/// longer exists.** `jeeb-gateway` #333 (`b6fe888`) deleted it together with the
/// 5 s server-side re-read loop it existed to open, and pinned the deletion:
/// `NoBackendPollOrFirestoreListenerGuardTests.Sse_Alias_Route_Is_Gone` requires
/// a **404** for a caller who WOULD have been authorized, and two structural
/// assertions ban the literals `text/event-stream` and `v1/geo/jeeb/stream` from
/// the shipped gateway assembly. Verified on the deployed MSI binary: a grep of
/// `publish/gateway/JeebGateway.dll` finds `deliveries/{deliveryId}/tracking`
/// (positive control) and finds `v1/geo/jeeb/stream` **zero** times.
///
/// The consequence was the courier-marker P0. The jeeber's
/// `POST /location/update` was 200-ing and the gateway was storing the fix, but
/// the customer asked a deleted URL, got 404, and `_onPositionStreamClosed`
/// re-armed it forever — so the "ERROR-RECOVERY" backoff below had quietly
/// become a permanent 30 s poll against a route that could never answer. Both
/// the stream and that timer are deleted here.
///
/// ## The cadence question, stated rather than hidden
///
/// The position is now read on exactly the events this cubit already had — first
/// mount, every `type=delivery` push, `retry()`, and app resume — and on NO
/// clock. `armed-poll-inventory.py` therefore still reports
/// `armedPollCount = 0`.
///
/// The honest cost: between two such events the marker does not move. Making it
/// track the jeeber continuously needs a push/subscribe transport for the
/// position axis, and **none currently exists** — the gateway may not hold an
/// SSE connection (guard above), may not take a Firestore dependency
/// (`Gateway_Assembly_References_No_Firestore_Client_Library`), the
/// realtime-comunication-service is not deployed for Jeeb, and every push send
/// endpoint attaches a notification block so a position push would light the
/// shade. That is an owner/architecture decision, not something to paper over
/// with a timer.
///
/// **Unchanged restraint (G4).** This screen still NEVER reads `GET /otp`. On the
/// live gateway that endpoint TRIGGERS AN SMS, so any cadence against it texts
/// the recipient repeatedly. The hand-over code comes from [HandoverCodeStore]
/// (local, accept-time) and from nowhere else.
class LiveTrackingCubit extends Cubit<LiveTrackingState> {
  LiveTrackingCubit({
    required LiveTrackingRepository repository,
    required this.deliveryId,
    Stream<void>? refreshSignals,
    HandoverCodeStore? handoverCodeStore,
  })  : _repository = repository,
        _refreshSignals = refreshSignals,
        _handoverCodeStore = handoverCodeStore,
        super(const LiveTrackingState()) {
    _fetchAndSchedule();
  }

  final LiveTrackingRepository _repository;
  final String deliveryId;

  /// Payload-less push→refetch bus for the STATUS axis. Every event is ONE
  /// `fetchDeliveryStatus`; there is no cadence behind it. `null` in a bare test
  /// with no DI, which then only reads on construction / retry / resume.
  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;

  /// True once the status push subscription is armed.
  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  /// How many courier-position snapshots have actually been READ off the
  /// gateway (not merely attempted).
  ///
  /// Deliberately counts ARRIVALS, not arming — the instrument it replaces
  /// (`debugPositionStreamWired`) returned `true` for a stream that had been
  /// opened once and had been dead for the rest of the screen's life, which is
  /// how a 404-ing feed went unnoticed for four days. A counter that only moves
  /// when a body came back cannot tell that lie.
  @visibleForTesting
  int get debugPositionReadCount => _positionReadCount;
  int _positionReadCount = 0;

  /// Single-flight latch for the push path: two pushes inside one round trip
  /// must produce ONE re-pull, not two whose emits race.
  bool _statusReadInFlight = false;

  /// G4: local, restart-safe source of the delivery hand-over code (persisted
  /// at offer-accept time). Read-only here — the tracking surface renders it
  /// discoverably pre-at-door and prominently at the door. It deliberately
  /// NEVER calls `GET /otp` (that endpoint is an SMS trigger on the live
  /// gateway — polling it would spam the recipient with texts).
  final HandoverCodeStore? _handoverCodeStore;
  /// Nothing more is worth watching for. Two INDEPENDENT axes, deliberately:
  ///  * lifecycle — [DeliveryTrackingInfo.isPollTerminal] (`cancelled` or
  ///    `expired`). P6/A3 split `expired` out of `isCancelled`, so this must
  ///    read `isPollTerminal`, NOT `isCancelled`: `isCancelled` alone would
  ///    silently keep polling an expired row forever.
  ///  * stage — `delivered`. A completed row never advances again (FM-4).
  ///
  /// `FailedNeedsEscalation` (`isUnderReview`) is deliberately EXCLUDED from
  /// both: SM edges 12/13 (`admin_resolve → Done`, `admin_cancel → Cancelled`)
  /// can still move it, so the screen must keep watching it (P6/A1).
  bool get _isTerminal =>
      (state.trackingInfo?.isPollTerminal ?? false) ||
      (state.trackingInfo?.isDelivered ?? false);

  Future<void> _fetchAndSchedule() async {
    await Future.wait([_hydrateHandoverCode(), _fetch()]);
    _armWatchers();
  }

  /// One push → one status read. Single-flighted; the terminal check inside
  /// [_fetch] retires both watchers when the row dies.
  Future<void> _refreshFromPush() async {
    if (isClosed || _isTerminal || _statusReadInFlight) return;
    _statusReadInFlight = true;
    try {
      await _fetch();
    } finally {
      _statusReadInFlight = false;
    }
    _armWatchers();
  }

  /// G4: re-hydrates the accept-time code from local persistence (cold-start
  /// safe). Total: a prefs failure just leaves the code null.
  Future<void> _hydrateHandoverCode() async {
    final store = _handoverCodeStore;
    if (store == null) return;
    try {
      final code = await store.read(deliveryId: deliveryId);
      if (code != null && !isClosed) {
        emit(state.copyWith(handoverCode: code));
      }
    } catch (_) {
      // Never let a local read fault the tracking surface.
    }
  }

  Future<void> _fetch() async {
    try {
      final info =
          await _repository.fetchDeliveryStatus(deliveryId: deliveryId);
      if (!isClosed) {
        emit(state.copyWith(
          mode: LiveTrackingViewMode.ready,
          trackingInfo: info,
          clearError: true,
          pendingEvent: _detectEvent(info),
        ));
        // sprint-009 scenario matrix #9 + P6/A1: a delivered, cancelled, or
        // expired delivery is terminal — stop watching a dead row (the screen
        // renders the graceful terminal state instead of a live stepper). A
        // `failed` (FailedNeedsEscalation) row KEEPS watching: an admin can
        // still resolve it to Done or cancel it, so it is not terminal here.
        //
        if (_isTerminal) _retireWatchers();
      }
      // The courier position rides the SAME event that just refreshed the
      // status — one round trip per event, never a cadence. Sequenced AFTER the
      // status emit rather than raced with it: `_applyLivePosition` merges onto
      // `state.trackingInfo`, so it must see the row this fetch just wrote or
      // the overlay lands on a stale snapshot (or, on first mount, on `null`
      // and is dropped entirely — which is exactly how the marker stayed
      // missing on the very first read).
      if (!isClosed && !_isTerminal) await _readLivePosition();
    } on LiveTrackingException catch (e) {
      if (!isClosed) {
        if (state.trackingInfo == null) {
          emit(state.copyWith(
            mode: LiveTrackingViewMode.error,
            errorMessage: _mapError(e.kind),
            errorTitle: _mapErrorTitle(e.kind),
          ));
        }
      }
    }
  }

  /// Reads ONE courier-position snapshot and merges it onto the row.
  ///
  /// Feature-detected (`repo is LivePositionSource`) exactly as the stream used
  /// to be, so the debug demo repo, the devtool seams and the `:4010` mock —
  /// none of which serve a tracking route — contribute no marker instead of
  /// faulting.
  ///
  /// Total by construction: [LivePositionSource.fetchLivePosition] swallows
  /// every transport failure into `null`, and this adds nothing that can throw.
  /// A dead position read must never fault a screen whose stepper and summary
  /// are fine.
  Future<void> _readLivePosition() async {
    final repo = _repository;
    // Explicit cast, not promotion: `LivePositionSource` is not a subtype of
    // `LiveTrackingRepository` (that is the whole point of keeping it a separate
    // optional capability), so Dart cannot promote across the two.
    if (repo is! LivePositionSource) return;
    final source = repo as LivePositionSource;
    final overlay = await source.fetchLivePosition(deliveryId: deliveryId);
    if (overlay == null || isClosed) return;
    _positionReadCount++;
    _applyLivePosition(overlay);
  }

  /// JEBV4-269: merge one position snapshot onto the current row so the map
  /// marker appears where the jeeber last reported.
  ///
  /// Three invariants, all load-bearing:
  ///  * The merge emit carries NO `pendingEvent` (`copyWith` resets it to
  ///    `none`), so a moving marker can never re-fire the at-door / delivered
  ///    navigation. An overlay landing right after the delivered transition
  ///    would otherwise re-push the receipt screen.
  ///  * An EMPTY overlay is dropped rather than merged, so the pre-first-fix
  ///    case cannot blank a marker the screen already has.
  ///  * A STALE overlay is NOT dropped — it is merged, carrying
  ///    `stale: true`, so `markerIsLive` goes false and the map stops drawing
  ///    the marker while the screen retains the age to explain itself. Dropping
  ///    it would leave the phantom on screen forever, which is the failure the
  ///    negative control exists to catch.
  void _applyLivePosition(DeliveryLivePosition overlay) {
    if (isClosed || overlay.isEmpty) return;
    final current = state.trackingInfo;
    if (current == null) return;
    emit(state.copyWith(
      trackingInfo: current.withLivePosition(
        jeeberPosition: overlay.jeeberPosition,
        polyline: overlay.polyline,
        stale: overlay.stale,
        secondsSinceUpdate: overlay.secondsSinceUpdate,
      ),
    ));
  }

  /// T-MOB-017 AC3/AC4 + JM-032 AC2: detect stage transitions and emit one-shot
  /// events. Delivered fires even on the FIRST fetch (no prior stage) so a cold
  /// poll that already reads `Done` still auto-advances to the receipt prompt.
  LiveTrackingEvent _detectEvent(DeliveryTrackingInfo info) {
    final prev = state.trackingInfo?.currentStage;
    final next = info.currentStage;
    // JM-032 AC2: terminal delivered → auto-advance. Guarded so it only fires
    // on the transition INTO delivered (or the first read of it), never again.
    if (next == TrackingStage.delivered &&
        prev != TrackingStage.delivered) {
      return LiveTrackingEvent.deliveredAutoAdvance;
    }
    if (prev == next) return LiveTrackingEvent.none;
    if (next == TrackingStage.atDoor) return LiveTrackingEvent.jeeberAtDoor;
    if (next == TrackingStage.inTransit) {
      return LiveTrackingEvent.jeeberOnTheWay;
    }
    return LiveTrackingEvent.none;
  }

  /// Arm the push watcher for a live row; retire it for a dead one.
  ///
  /// Never arms for a delivered, cancelled or expired delivery — the FIRST fetch
  /// may already have read the terminal row (scenario matrix #9), in which case
  /// nothing should ever be subscribed. An escalated `failed` row is NOT terminal
  /// here and keeps watching (P6/A1): SM edges 12/13 can still resolve it.
  ///
  /// Idempotent (`??=`), so it is safe to call from construction, retry, resume
  /// and the push path.
  ///
  /// There is no second watcher any more. The position axis is not subscribed to
  /// — it is read inside [_fetch], on the same events — so there is nothing here
  /// to arm, nothing to re-arm, and no timer to leak.
  void _armWatchers() {
    if (isClosed) return;
    if (_isTerminal) {
      _retireWatchers();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
  }

  /// Stop watching. `cancel()`'s future is deliberately NOT awaited: once it
  /// RETURNS no further events are delivered, nulling the field is what makes
  /// that observable, and awaiting a cancel from `close()` deadlocks the
  /// fake-async zone under `testWidgets`.
  void _retireWatchers() {
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
  }

  void retry() {
    emit(state.copyWith(mode: LiveTrackingViewMode.loading, clearError: true));
    _fetchAndSchedule();
  }

  /// JEBV4-282: force an immediate re-fetch + re-arm the watchers. The screen
  /// wires this to app-resume (`live_tracking_screen.dart:641-645`).
  ///
  /// This is now MORE load-bearing than it was, not less: it is the backstop for
  /// a `type=delivery` push the OS dropped or coalesced while the process was
  /// backgrounded, AND — because [_fetch] now reads the position too — it is the
  /// user's own way to move the courier marker forward. Explicitly allowed by
  /// the mandate: the read is caused by the user returning to the app, not by a
  /// clock.
  ///
  /// Silent (no loading flash): [_fetch] keeps the last good `trackingInfo` on a
  /// failure, and a delivered/cancelled/expired row is left untouched (nothing
  /// left to watch). An escalated `failed` row still refreshes — admin
  /// resolution must land (P6/A1).
  /// Single-flighted with the push path via [_statusReadInFlight]. This is not
  /// belt-and-braces: `didChangeAppLifecycleState(resumed)` can fire MORE THAN
  /// ONCE for a single background→foreground trip (the platform/test binding
  /// normalizes `paused → hidden → inactive → resumed` and notifies along the
  /// way), and the screen's hook posts a frame callback on each. Without the
  /// latch that is two full `GET /v1/deliveries/{id}` round trips on every app
  /// switch — which is exactly the traffic this change exists to remove, and it
  /// went unnoticed in the poll era because the poll's own ticks buried it.
  Future<void> refreshNow() async {
    if (isClosed) return;
    if (_isTerminal) return;
    if (_statusReadInFlight) return;
    _statusReadInFlight = true;
    try {
      await _fetch();
    } finally {
      _statusReadInFlight = false;
    }
    if (!isClosed) _armWatchers();
  }

  String _mapError(LiveTrackingErrorKind kind) {
    switch (kind) {
      case LiveTrackingErrorKind.network:
        return 'Unable to connect. Check your internet.';
      case LiveTrackingErrorKind.server:
        return 'Server error. Please try again.';
      case LiveTrackingErrorKind.notFound:
        // S9 live-tracking fix: a 404 is a genuine "no delivery to track yet"
        // state, not a server fault. Keep it calm and offer a retry (the
        // accept-minted delivery may still be propagating).
        return "We can't find this delivery yet. It may still be getting "
            'ready — pull to retry in a moment.';
      case LiveTrackingErrorKind.parse:
        return 'Unexpected response format.';
    }
  }

  /// A distinct heading for the 404 empty/error state; null for the generic
  /// errors (which read fine with just a message).
  String? _mapErrorTitle(LiveTrackingErrorKind kind) {
    switch (kind) {
      case LiveTrackingErrorKind.notFound:
        return 'Delivery not found';
      case LiveTrackingErrorKind.network:
      case LiveTrackingErrorKind.server:
      case LiveTrackingErrorKind.parse:
        return null;
    }
  }

  @override
  Future<void> close() {
    _retireWatchers();
    return super.close();
  }
}
