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
///  * **Courier position is a STREAM.** Continuous while en route. No push
///    carries it and none should: every gateway send endpoint attaches a
///    notification block, so a position push would light the shade several times
///    a minute. The gateway already serves it as server-sent events; SSE is
///    server-push (one held connection, server writes when it has a fix) and so
///    does not breach the no-polling rule. → [LivePositionStreamSource], via
///    `SseLivePositionStream`. Retires `GET /deliveries/{id}/tracking`.
///
/// Deleting the poll without splitting these would have frozen the map marker:
/// the position would only refresh when a STATUS changed, which during
/// `InTransit` is almost never.
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
  StreamSubscription<DeliveryLivePosition>? _positionSubscription;

  /// True once the status push subscription is armed.
  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  /// True once the SSE position stream is subscribed.
  @visibleForTesting
  bool get debugPositionStreamWired => _positionSubscription != null;

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
        // Retiring the POSITION stream matters more than retiring a timer did:
        // an SSE socket left open after delivery keeps the gateway writing into
        // a connection nobody reads for the rest of the session. (The gateway
        // also breaks its own loop on a terminal status at
        // `Controllers/LocationController.cs:392-397`, so this is belt AND
        // braces — but the client must not depend on the server to hang up.)
        if (_isTerminal) _retireWatchers();
      }
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

  /// JEBV4-269 (b02 wave C / N7): merge one SERVER-PUSHED position frame onto the
  /// current snapshot so the map marker moves.
  ///
  /// This is the SAME merge the old `_overlayLivePosition` performed — the only
  /// change is where the overlay comes from. It used to be a one-shot
  /// `GET /deliveries/{id}/tracking` read issued from inside every `_fetch`, i.e.
  /// on the 5s poll cadence; it now arrives from the gateway's SSE stream with no
  /// client cadence at all.
  ///
  /// Two invariants carried over verbatim, both load-bearing:
  ///  * The merge emit carries NO `pendingEvent` (`copyWith` resets it to
  ///    `none`), so a moving marker can never re-fire the at-door / delivered
  ///    navigation. A frame arriving right after the delivered transition would
  ///    otherwise re-push the receipt screen.
  ///  * An empty overlay is DROPPED (upstream, in `SseLivePositionStream`) rather
  ///    than merged, so the pre-first-fix case cannot blank a marker the screen
  ///    already has.
  void _applyLivePosition(DeliveryLivePosition overlay) {
    if (isClosed || overlay.isEmpty) return;
    final current = state.trackingInfo;
    if (current == null) return;
    emit(state.copyWith(
      trackingInfo: current.withLivePosition(
        jeeberPosition: overlay.jeeberPosition,
        polyline: overlay.polyline,
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

  /// Arm both watchers for a live row; retire both for a dead one.
  ///
  /// Never arms for a delivered, cancelled or expired delivery — the FIRST fetch
  /// may already have read the terminal row (scenario matrix #9), in which case
  /// nothing should ever be subscribed. An escalated `failed` row is NOT terminal
  /// here and keeps both watchers (P6/A1): SM edges 12/13 can still resolve it.
  ///
  /// Idempotent (`??=`), so it is safe to call from construction, retry, resume
  /// and the push path.
  void _armWatchers() {
    if (isClosed) return;
    if (_isTerminal) {
      _retireWatchers();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
    // The POSITION axis is feature-detected, exactly as the old one-shot
    // `LivePositionSource` was: the `:4010` mock has no tracking route at all,
    // so a repo that cannot stream contributes no marker rather than faulting.
    final repo = _repository;
    if (repo is LivePositionStreamSource && _positionSubscription == null) {
      final source = repo as LivePositionStreamSource;
      // The stream never emits an error by contract (see
      // `LivePositionStreamSource`); a dead feed arrives as onDone and is
      // recorded by the SSE layer's `tracking_sse` diag breadcrumb, so a frozen
      // marker is never silent in the journal.
      _positionSubscription = source
          .watchLivePosition(deliveryId: deliveryId)
          .listen(_applyLivePosition);
    }
  }

  /// Stop both watchers. `cancel()`'s future is deliberately NOT awaited: once it
  /// RETURNS no further events are delivered, nulling the fields is what makes
  /// that observable, and awaiting a cancel from `close()` deadlocks the
  /// fake-async zone under `testWidgets`.
  void _retireWatchers() {
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
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
  /// backgrounded, AND it re-opens the SSE position stream, which the OS will
  /// have torn down along with the socket. Explicitly allowed by the mandate —
  /// the read is caused by the user returning to the app, not by a clock.
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
