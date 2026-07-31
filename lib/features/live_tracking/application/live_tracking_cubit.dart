import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'live_tracking_state.dart';

/// Diag event name emitted ONCE per tracking-screen entry (one cubit = one
/// entry, because the route builder constructs it in `create:`).
///
/// It exists so a device capture can state its own denominator: "N positions
/// within ONE dwell" is only a measurement if the number of dwells is known.
/// Counting three positions across three screen entries proves nothing about a
/// marker that moves — it proves the screen reads on open, which is trivially
/// true. See `docs/execution/batches/MB1.md`.
const String kTrackingScreenOpenEvent = 'tracking_screen_open';

/// Diag event name emitted for every ATTEMPTED live-position read, whether or
/// not it produced a fix.
///
/// Payload: `deliveryId`, `cause` ([LivePositionReadCause.wire]), `applied`
/// (did the overlay actually land on the snapshot), `lat`/`lng` (null when the
/// gateway has no fix yet) and `polyline` (point count).
///
/// A failed/empty read is deliberately still recorded: a frozen marker with
/// nothing in the journal is indistinguishable from a marker nobody looked at,
/// and that ambiguity has already cost this programme a whole device round.
const String kTrackingPositionEvent = 'tracking_position';

/// What caused a live-position read. There is no other way to cause one — this
/// enum IS the exhaustive list of position triggers, and none of them is a
/// clock.
enum LivePositionReadCause {
  /// The customer opened the tracking screen (cubit construction).
  screenOpen('open'),

  /// A `type=delivery` push arrived on [LiveTrackingCubit]'s refresh bus.
  push('push'),

  /// The app returned to the foreground (`refreshNow`, the resume backstop).
  resume('resume'),

  /// The customer tapped retry on the error state.
  retry('retry');

  const LivePositionReadCause(this.wire);

  /// The literal written to the `cause` field of [kTrackingPositionEvent].
  final String wire;
}

/// b02 wave C — N7 / MB1 W1.1. This cubit runs NO cadence of any kind. Both of
/// its data needs are driven by events:
///
///  * **Status transitions are EVENTS.** Discrete and rare. The gateway's
///    `type=delivery` push carries them and reaches the CUSTOMER —
///    `NotifyOtherPartyAsync` puts `req.ClientId` on the recipient list
///    (`Controllers/DeliveriesController.cs:1296-1300`) and
///    `Notifications/DeliveryStatusPushNotifier.cs:211` stamps the
///    `type=delivery` + snake_case `delivery_id` pair the mobile handler's
///    `orderish` id guard requires. → [refreshSignals]. Retires
///    `GET /v1/deliveries/{id}` as a poll.
///  * **Courier position is a SNAPSHOT read, taken on the same events.** One
///    `GET /deliveries/{id}/tracking` per screen-open, per status push, per
///    resume and per retry — and at no other time. → [LivePositionSource].
///
/// **MB1 W1.1 — why the SSE stack is gone.** The previous revision of this file
/// subscribed to the gateway's server-sent-events position alias under
/// `/v1/geo/`, through a streaming capability interface and its Dio consumer,
/// and re-armed the subscription on a widening backoff constant whenever it
/// closed. The gateway **deleted that route** 16 h after the consumer landed —
/// `LocationController.cs:22-31` says so in as many words, that the
/// `Accept: text/event-stream` arm was a 5 s server-side re-read loop and *"is
/// deleted, along with the … alias that existed only to open it"*. So every arm
/// 404'd, every 404 closed the stream, and the re-arm counter — reset ONLY
/// inside the frame handler of a stream that could never deliver a frame — sat
/// at its 30 s steady state issuing a dead GET forever. A customer-facing P0:
/// a permanently frozen courier marker plus an unbounded loop of failed
/// requests.
///
/// The deleted symbols are named nowhere in this repo on purpose. A verifier
/// greps the tree, not the AST, so a doc comment quoting the dead route reads
/// exactly like a live caller — see
/// `test/features/live_tracking/sse_teardown_grep_receipt_test.dart`, which is
/// the standing guard and the only file allowed to spell them out.
///
/// The replacement is the read the gateway actually still serves
/// (`LocationController.cs:227`, `[HttpGet("deliveries/{deliveryId}/tracking")]`
/// → one-shot JSON snapshot, no held connection). No new cadence was
/// introduced: the position read rides the events that already existed.
///
/// **Unchanged restraint (G4).** This screen still NEVER reads `GET /otp`. On
/// the live gateway that endpoint TRIGGERS AN SMS, so any cadence against it
/// texts the recipient repeatedly. The hand-over code comes from
/// [HandoverCodeStore] (local, accept-time) and from nowhere else.
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
    // ONE per screen entry — the denominator for every position claim. Emitted
    // before the first read so the record order in a capture is
    // open → position, never the reverse.
    Diag.event(kTrackingScreenOpenEvent, <String, Object?>{
      'deliveryId': deliveryId,
      // Whether this repo can serve a position at all. The `:4010` mock and the
      // demo/seam doubles cannot, and a capture taken against one of them must
      // not be read as "the marker is broken".
      'positionSource': repository is LivePositionSource,
    });
    _fetchAndSchedule(LivePositionReadCause.screenOpen);
  }

  final LiveTrackingRepository _repository;
  final String deliveryId;

  /// Payload-less push→refetch bus for the STATUS axis. Every event is ONE
  /// `fetchDeliveryStatus` plus ONE position read; there is no cadence behind
  /// it. `null` in a bare test with no DI, which then only reads on
  /// construction / retry / resume.
  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;

  /// True once the status push subscription is armed.
  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  /// How many live-position reads have been ATTEMPTED (one per emitted
  /// [kTrackingPositionEvent]). The host-side twin of the device capture, so a
  /// widget test can assert "no cadence" as a number rather than a vibe.
  @visibleForTesting
  int get debugPositionReadCount => _positionReadCount;
  int _positionReadCount = 0;

  /// What caused the most recent position read. Null before the first one.
  @visibleForTesting
  LivePositionReadCause? get debugLastPositionCause => _lastPositionCause;
  LivePositionReadCause? _lastPositionCause;

  /// Single-flight latch for the push path: two pushes inside one round trip
  /// must produce ONE re-pull, not two whose emits race.
  bool _statusReadInFlight = false;

  /// Single-flight latch for the POSITION path, for the same reason: a resume
  /// notification can fire more than once for one background→foreground trip,
  /// and two overlapping tracking reads would double the traffic this batch
  /// exists to remove.
  bool _positionReadInFlight = false;

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
  ///    silently keep reading an expired row forever.
  ///  * stage — `delivered`. A completed row never advances again (FM-4).
  ///
  /// `FailedNeedsEscalation` (`isUnderReview`) is deliberately EXCLUDED from
  /// both: SM edges 12/13 (`admin_resolve → Done`, `admin_cancel → Cancelled`)
  /// can still move it, so the screen must keep watching it (P6/A1).
  bool get _isTerminal =>
      (state.trackingInfo?.isPollTerminal ?? false) ||
      (state.trackingInfo?.isDelivered ?? false);

  Future<void> _fetchAndSchedule(LivePositionReadCause cause) async {
    await Future.wait([_hydrateHandoverCode(), _fetch()]);
    _armWatchers();
    await _readLivePosition(cause);
  }

  /// One push → one status read → one position read. Single-flighted; the
  /// terminal check inside [_fetch] retires the watcher when the row dies.
  Future<void> _refreshFromPush() async {
    if (isClosed || _isTerminal || _statusReadInFlight) return;
    _statusReadInFlight = true;
    try {
      await _fetch();
    } finally {
      _statusReadInFlight = false;
    }
    _armWatchers();
    await _readLivePosition(LivePositionReadCause.push);
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
          trackingInfo: _carryLastKnownPosition(info),
          clearError: true,
          pendingEvent: _detectEvent(info),
        ));
        // sprint-009 scenario matrix #9 + P6/A1: a delivered, cancelled, or
        // expired delivery is terminal — stop watching a dead row (the screen
        // renders the graceful terminal state instead of a live stepper). A
        // `failed` (FailedNeedsEscalation) row KEEPS watching: an admin can
        // still resolve it to Done or cancel it, so it is not terminal here.
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

  /// Carries the last known courier fix onto a freshly-read delivery row.
  ///
  /// `DeliveryTrackingInfo.fromDeliveryJson` NEVER populates `jeeberPosition` /
  /// `polyline` — the delivery row does not carry them; only
  /// `GET /deliveries/{id}/tracking` does. So a bare `trackingInfo: info` emit
  /// BLANKS the marker on every status read, and it always did: under the SSE
  /// design that was invisible only because frames arrived seconds later and
  /// re-drew it. On the snapshot path the two reads are adjacent, and if the
  /// gateway happens to have no fix at that instant (`fetchLivePosition` →
  /// null, its contract on 403/404/transport/parse) the marker would disappear
  /// mid-trip on a status change.
  ///
  /// Carrying it forward makes the screen strictly better than the stream
  /// version: the marker shows the LAST KNOWN fix and is only ever replaced by
  /// a newer one, never by nothing.
  DeliveryTrackingInfo _carryLastKnownPosition(DeliveryTrackingInfo info) {
    final previous = state.trackingInfo;
    if (previous == null) return info;
    if (previous.jeeberPosition == null && previous.polyline.isEmpty) {
      return info;
    }
    return info.withLivePosition(
      jeeberPosition: previous.jeeberPosition,
      polyline: previous.polyline,
    );
  }

  /// MB1 W1.1: ONE `GET /deliveries/{id}/tracking` read, caused by [cause].
  ///
  /// Feature-detected exactly as the stream source was — the `:4010` Express
  /// mock has no tracking route, and the demo/seam/catalog doubles implement
  /// only [LiveTrackingRepository] — so a repo that cannot serve a position
  /// contributes no marker instead of faulting the screen.
  ///
  /// Deliberately total downstream: [LivePositionSource.fetchLivePosition] is
  /// contractually null on ANY failure (403 not-a-party, 404 no-fix-yet,
  /// transport, malformed body), so the map simply keeps its last-known marker.
  ///
  /// Emits [kTrackingPositionEvent] on every attempt, including the null ones.
  Future<void> _readLivePosition(LivePositionReadCause cause) async {
    if (isClosed || _isTerminal) return;
    final repo = _repository;
    if (repo is! LivePositionSource) return;
    if (_positionReadInFlight) return;
    // Explicit cast, not promotion: `LivePositionSource` is deliberately NOT a
    // subtype of `LiveTrackingRepository` (that is the whole point of the
    // optional capability), so the `is!` guard above cannot promote `repo`.
    final source = repo as LivePositionSource;
    _positionReadInFlight = true;
    DeliveryLivePosition? overlay;
    try {
      overlay = await source.fetchLivePosition(deliveryId: deliveryId);
    } finally {
      _positionReadInFlight = false;
    }
    if (isClosed) return;
    final applied = _applyLivePosition(overlay);
    _positionReadCount++;
    _lastPositionCause = cause;
    Diag.event(kTrackingPositionEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'cause': cause.wire,
      'applied': applied,
      'lat': overlay?.jeeberPosition?.lat,
      'lng': overlay?.jeeberPosition?.lng,
      'polyline': overlay?.polyline.length ?? 0,
    });
  }

  /// JEBV4-269: merge one position snapshot onto the current row so the map
  /// marker moves. Returns whether anything was actually merged.
  ///
  /// Two invariants carried over verbatim, both load-bearing:
  ///  * The merge emit carries NO `pendingEvent` (`copyWith` resets it to
  ///    `none`), so a moving marker can never re-fire the at-door / delivered
  ///    navigation. A frame arriving right after the delivered transition would
  ///    otherwise re-push the receipt screen.
  ///  * An EMPTY overlay is DROPPED rather than merged, so the pre-first-fix
  ///    case cannot blank a marker the screen already has.
  bool _applyLivePosition(DeliveryLivePosition? overlay) {
    if (isClosed || overlay == null || overlay.isEmpty) return false;
    final current = state.trackingInfo;
    if (current == null) return false;
    emit(state.copyWith(
      trackingInfo: current.withLivePosition(
        jeeberPosition: overlay.jeeberPosition,
        polyline: overlay.polyline,
      ),
    ));
    return true;
  }

  /// T-MOB-017 AC3/AC4 + JM-032 AC2: detect stage transitions and emit one-shot
  /// events. Delivered fires even on the FIRST fetch (no prior stage) so a cold
  /// read that already reads `Done` still auto-advances to the receipt prompt.
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

  /// Arm the status watcher for a live row; retire it for a dead one.
  ///
  /// Never arms for a delivered, cancelled or expired delivery — the FIRST
  /// fetch may already have read the terminal row (scenario matrix #9), in
  /// which case nothing should ever be subscribed. An escalated `failed` row is
  /// NOT terminal here and keeps the watcher (P6/A1): SM edges 12/13 can still
  /// resolve it.
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
    _fetchAndSchedule(LivePositionReadCause.retry);
  }

  /// JEBV4-282: force an immediate re-fetch of BOTH axes. The screen wires this
  /// to app-resume (`live_tracking_screen.dart`, `_ResumeRefresh`).
  ///
  /// This is the backstop for a `type=delivery` push the OS dropped or coalesced
  /// while the process was backgrounded, AND it is what un-freezes the courier
  /// marker after a spell in the background. Explicitly allowed by the mandate —
  /// the read is caused by the user returning to the app, not by a clock.
  ///
  /// Silent (no loading flash): [_fetch] keeps the last good `trackingInfo` on a
  /// failure, and a delivered/cancelled/expired row is left untouched (nothing
  /// left to watch). An escalated `failed` row still refreshes — admin
  /// resolution must land (P6/A1).
  ///
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
    if (isClosed) return;
    _armWatchers();
    await _readLivePosition(LivePositionReadCause.resume);
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
