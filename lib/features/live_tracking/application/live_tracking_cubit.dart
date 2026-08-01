import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/courier_position_channel.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'live_tracking_state.dart';

/// Diag event name emitted ONCE per tracking-screen entry (one cubit = one
/// entry — the route builder constructs it in `create:`).
///
/// It exists so a device capture can state its own DENOMINATOR. "N positions in
/// one dwell" is only a measurement if the number of dwells is known; three
/// positions spread across three screen entries prove nothing about a marker
/// that moves, they prove the screen reads on open, which is trivially true.
///
/// MB1 V-2 counts exactly one of these per `deliveryId` under test and reads
/// every [kTrackingPositionEvent] against it.
const String kTrackingScreenOpenEvent = 'tracking_screen_open';

/// Diag event name emitted for EVERY attempted courier-position read — whether
/// or not it produced a fix, and whether or not the fix landed.
///
/// Payload: `deliveryId`, `cause` ([LivePositionReadCause.wire]), `applied`
/// (did the overlay actually merge onto the snapshot), `lat` / `lng` (null when
/// the gateway holds no fix), `polyline` (point count), `stale`, and `error`
/// (present ONLY when the read threw).
///
/// The empty and null reads are deliberately still recorded. A frozen marker
/// with nothing in the journal is indistinguishable from a marker nobody looked
/// at, and that exact ambiguity already cost this programme two device rounds:
/// a capture in which every `GET …/tracking` answered `"position":null` was
/// read as "the wire is broken" when it in fact measured the jeeber's GPS
/// uploader and the gateway's 5-minute TTL.
///
/// None of these keys is in `kSensitiveDataKeys`, so `DiagRedaction.scrubMap`
/// passes the coordinates through verbatim — checked, because a redacted `lat`
/// would make MB1's MARKER leg unmeasurable.
const String kTrackingPositionEvent = 'tracking_position';

/// Diag event name emitted for every courier position that ARRIVES on the
/// realtime subscription (as opposed to one this screen went and read).
///
/// Payload: `deliveryId`, `lat`, `lng`, `applied` (did it land on the snapshot),
/// and `n` (how many frames this screen entry has taken, so a capture can state
/// its own rate without timestamps arithmetic).
///
/// **Deliberately NOT folded into [kTrackingPositionEvent].** That event's
/// contract is "one record per attempted READ", and MB1's V-2 leg counts those
/// records against a [kTrackingScreenOpenEvent] denominator to prove the screen
/// is not reading on a clock. Pushing subscription arrivals into the same
/// stream would inflate that count with events that are not reads at all, and
/// the instrument that proves "no cadence" would start reporting a cadence —
/// on the very change that removes the need for one.
///
/// A device capture reads the two together: `tracking_position` says how many
/// times the screen ASKED, `tracking_stream_position` says how many times it
/// was TOLD.
const String kTrackingStreamPositionEvent = 'tracking_stream_position';

/// What caused a courier-position read.
///
/// This enum IS the exhaustive list of position triggers, and the point of it
/// is that **none of them is a clock**. If a fifth arm ever appears here, the
/// reviewer's first question should be whether it is a cadence in disguise.
enum LivePositionReadCause {
  /// The customer opened the tracking screen (cubit construction).
  screenOpen('open'),

  /// A `type=delivery` push arrived on [LiveTrackingCubit]'s refresh bus.
  push('push'),

  /// The app returned to the foreground — `refreshNow`, the resume backstop.
  resume('resume'),

  /// The customer tapped retry on the error state.
  retry('retry');

  const LivePositionReadCause(this.wire);

  /// The literal written to the `cause` field of [kTrackingPositionEvent].
  /// Short on purpose: it is read out of a logcat capture by eye as often as
  /// by parser.
  final String wire;
}

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
/// The bullet above used to read "*Courier position is a STREAM*", served by an
/// SSE client class over a `geo` alias route. **That route no longer exists.**
/// `jeeb-gateway` #333 (`b6fe888`) deleted it together with the 5 s server-side
/// re-read loop it existed to open, and pinned the deletion:
/// `NoBackendPollOrFirestoreListenerGuardTests.Sse_Alias_Route_Is_Gone` requires
/// a **404** for a caller who WOULD have been authorized, and two structural
/// assertions ban both the event-stream content type and the alias path from the
/// shipped gateway assembly. Verified on the deployed MSI binary: a grep of
/// `publish/gateway/JeebGateway.dll` finds `deliveries/{deliveryId}/tracking`
/// (positive control) and finds the alias **zero** times.
///
/// The alias path and the deleted Dart class are deliberately NOT spelled out
/// anywhere in this repo any more — MB1's V-1 contract greps the whole tree for
/// them and a doc comment is indistinguishable from a live call site to `grep`.
/// `Sse_Alias_Route_Is_Gone` is the durable handle: it names the authoritative
/// artifact instead of repeating a URL that 404s.
///
/// The consequence was the courier-marker P0. The jeeber's
/// `POST /location/update` was 200-ing and the gateway was storing the fix, but
/// the customer asked a deleted URL, got 404, and the stream's close handler
/// re-armed it forever — so the "ERROR-RECOVERY" backoff had quietly become a
/// permanent 30 s poll against a route that could never answer. (Not a flat 30 s
/// loop: the re-arm schedule fired at 2 / 5 / 15 / 30 s and then saturated,
/// because its reset site sat inside a frame handler a dead route never reached.)
/// Both the stream and that timer are deleted.
///
/// ## The cadence question, stated rather than hidden
///
/// The position is now read on exactly the events this cubit already had — first
/// mount, every `type=delivery` push, `retry()`, and app resume — and on NO
/// clock. `armed-poll-inventory.py` therefore still reports
/// `armedPollCount = 0`.
///
/// The honest cost: between two such events the marker does not move — it JUMPS
/// rather than glides.
///
/// ## The subscription that fixes that, and what it does NOT change
///
/// A push/subscribe transport for the position axis now exists.
/// **jeeb-gateway #339** (`3c1015d`) publishes every accepted
/// `POST /location/update` to `jeeb:delivery:{deliveryId}` / stream `location`
/// on realtime-comunication-service, and serves
/// `GET /v1/realtime/jeeb:delivery:{id}` — a fail-closed descriptor handing a
/// party a subscribe-only credential scoped to that one topic. This cubit takes
/// an optional [CourierPositionChannel] over it.
///
/// The paragraph above about a cadence still holds, unchanged, and that is the
/// point:
///
///  * the four read triggers are **untouched** — mount, push, resume, retry;
///  * the subscription **adds no timer to this cubit**. It arms once, and every
///    marker move after that is caused by a frame the server sent unbidden;
///  * with the flag off, a `null` `socketUrl`, a refused join, or a socket that
///    dies mid-delivery, [_positionChannel] contributes exactly nothing and
///    this screen is byte-for-byte the screen described above.
///
/// It is deliberately **not** an SSE stream and takes no Firestore dependency,
/// so `NoBackendPollOrFirestoreListenerGuardTests` is untouched: the gateway
/// does not proxy the socket, and the client talks to the realtime service
/// directly with a credential the gateway minted.
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
    CourierPositionChannel? positionChannel,
  })  : _repository = repository,
        _refreshSignals = refreshSignals,
        _handoverCodeStore = handoverCodeStore,
        _positionChannel = positionChannel,
        super(const LiveTrackingState()) {
    // MB1 W1.1b: the denominator, emitted BEFORE the first read so it can never
    // be ordered after the position record it is supposed to bound.
    Diag.event(kTrackingScreenOpenEvent, <String, Object?>{
      'deliveryId': deliveryId,
    });
    _fetchAndSchedule(LivePositionReadCause.screenOpen);
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

  /// OPTIONAL push transport for the courier position — `null` on every
  /// deployment, build and test that has not opted in, which is the default.
  /// See the class doc: with it null this cubit is exactly what it was.
  final CourierPositionChannel? _positionChannel;

  /// The live leg. Named to survive MB1's repo-wide grep receipts, which forbid
  /// the identifier the deleted SSE client used
  /// (`sse_teardown_grep_receipt_test.dart`).
  StreamSubscription<CourierPositionFix>? _streamedPositionLeg;

  /// ARM-ONCE latch.
  ///
  /// Set before the first `open()` and never cleared, so:
  ///   * a channel that cannot open (flag off is handled upstream; here it is a
  ///     403/404/503, a null socketUrl, or an unreachable host) costs exactly
  ///     ONE descriptor GET per screen entry, not one per resume;
  ///   * a socket that dies mid-delivery is NOT re-dialled. That is the
  ///     specified degradation — the screen falls back to precisely the four
  ///     triggers it had before — and it is also the only shape that cannot
  ///     become a reconnect loop, i.e. a timer whose tick reads the gateway.
  ///     Re-entering the tracking screen builds a new cubit and re-arms.
  bool _positionStreamArmed = false;

  /// How many courier positions have ARRIVED on the subscription during this
  /// screen entry.
  ///
  /// The MARKER-MOVES instrument. Counts arrivals, never arming — the same
  /// discipline as [debugPositionReadCount], and for the same reason: an
  /// "is the socket wired" boolean returned `true` for a feed that had been
  /// dead for four days.
  @visibleForTesting
  int get debugStreamedPositionCount => _streamedPositionCount;
  int _streamedPositionCount = 0;

  /// True once the subscription leg is live. Distinct from
  /// [debugStreamedPositionCount] on purpose: this one CAN lie about health
  /// (that is the failure mode it is named after), so tests assert the counter
  /// for behaviour and this only for wiring.
  @visibleForTesting
  bool get debugPositionStreamLegArmed => _streamedPositionLeg != null;

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

  /// TRAILING EDGE of the push single-flight above. Set when a push lands while
  /// a push-driven read is already in flight; consumed once that read completes.
  ///
  /// Dropping the overlapping push outright — which is what this code did on
  /// `origin/main` — is wrong specifically BECAUSE there is no cadence. With a
  /// poll, a dropped edge is repaired by the next tick; here the row and the
  /// marker simply stay at the pre-push snapshot until some later, unrelated
  /// event happens to arrive. A second push landing inside the first push's
  /// round trip is the COMMON case whenever the jeeber is moving, and it takes
  /// the `cause:'push'` breadcrumb with it, so the capture then shows silence
  /// where a refresh actually happened.
  ///
  /// This is COALESCING, not cadence, and it is bounded by construction: the
  /// flag holds at most one deferred edge, it is only ever set by an EXTERNAL
  /// push event, and a completed read with the flag clear schedules nothing.
  /// N pushes therefore produce at most N+1 reads and **zero** timers.
  bool _pendingPushEdge = false;

  /// Single-flight latch for the position read: two causes inside one round
  /// trip must produce ONE read, not two whose emits race — an older snapshot
  /// completing after a newer one would otherwise overwrite the fresh marker
  /// with a stale one.
  bool _positionReadInFlight = false;

  /// TRAILING EDGE of the position single-flight above. Set when a cause arrives
  /// while a read is already in flight; consumed once that read completes.
  ///
  /// Same reasoning as [_pendingPushEdge], one layer down: a push landing inside
  /// the screen-open round trip is the common case (the open read is a full
  /// network round trip and the push that woke the screen is right behind it).
  /// Dropping it would leave the marker at the pre-push snapshot AND remove the
  /// `cause:'push'` row that MB1's V-2 contract counts.
  ///
  /// One slot, LAST cause wins (it is the most recent reason to believe the
  /// marker is stale), filled only by an external event, and a completed read
  /// with an empty slot schedules nothing. N events produce at most N+1 reads
  /// and **zero** timers — `async.periodicTimerCount == 0` and
  /// `async.pendingTimers.isEmpty` are asserted against exactly this, so "no new
  /// cadence" still holds.
  LivePositionReadCause? _pendingPositionCause;

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

  Future<void> _fetchAndSchedule(LivePositionReadCause cause) async {
    await Future.wait([_hydrateHandoverCode(), _fetch(cause)]);
    _armWatchers();
  }

  /// One push → one status read. Single-flighted, and COALESCED onto a trailing
  /// edge rather than dropped; the terminal check inside [_fetch] retires the
  /// watcher when the row dies.
  ///
  /// The `return` on [_statusReadInFlight] used to be an outright drop. See
  /// [_pendingPushEdge] — under a push-only transport with no cadence, nothing
  /// ever heals a dropped edge, so the screen froze at the pre-push snapshot.
  Future<void> _refreshFromPush() async {
    if (isClosed || _isTerminal) return;
    if (_statusReadInFlight) {
      _pendingPushEdge = true;
      return;
    }
    _statusReadInFlight = true;
    try {
      await _fetch(LivePositionReadCause.push);
    } finally {
      _statusReadInFlight = false;
    }
    _armWatchers();
    // Drain the coalesced edge, if any. Cleared BEFORE the recursive call so a
    // push landing during the drain re-arms it instead of being swallowed, and
    // so this can never loop without a new external event.
    if (!_pendingPushEdge) return;
    _pendingPushEdge = false;
    await _refreshFromPush();
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

  Future<void> _fetch(LivePositionReadCause cause) async {
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
      if (!isClosed && !_isTerminal) await _readLivePosition(cause);
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
  ///
  /// MB1 W1.1b — the instrument. Exactly one [kTrackingPositionEvent] is emitted
  /// per ATTEMPT that reached the gateway client, including the attempts that
  /// come back `null` or empty. Emitting only the successes would reproduce the
  /// defect the old `debugPositionStreamWired` had: a silent feed and a healthy
  /// feed look identical from the capture.
  ///
  /// The `is! LivePositionSource` early return emits nothing on purpose — no
  /// read was attempted there, and a record claiming otherwise would put phantom
  /// rows in the denominator for every devtool seam and demo repo.
  Future<void> _readLivePosition(LivePositionReadCause cause) async {
    if (isClosed || _isTerminal) return;
    final repo = _repository;
    // Explicit cast, not promotion: `LivePositionSource` is not a subtype of
    // `LiveTrackingRepository` (that is the whole point of keeping it a separate
    // optional capability), so Dart cannot promote across the two.
    if (repo is! LivePositionSource) return;
    if (_positionReadInFlight) {
      // Coalesce onto the trailing edge instead of dropping the cause. See
      // [_pendingPositionCause] — the LAST cause wins, because it is the most
      // recent reason to believe the marker is stale.
      _pendingPositionCause = cause;
      return;
    }
    final source = repo as LivePositionSource;
    _positionReadInFlight = true;
    DeliveryLivePosition? overlay;
    String? failure;
    try {
      overlay = await source.fetchLivePosition(deliveryId: deliveryId);
    } catch (e) {
      // `fetchLivePosition` is DOCUMENTED total and the shipped implementation
      // is. A different one — a devtool double, a seam fake, a future client —
      // is not bound by that doc comment, and an error escaping here would ride
      // out through the unawaited `_fetchAndSchedule` as an unhandled zone
      // error, killing the breadcrumb on the way out. Record it and keep
      // showing the last known marker: a swallowed error that is NAMED in the
      // capture is strictly more observable than a crash that is not.
      failure = e.runtimeType.toString();
    } finally {
      _positionReadInFlight = false;
    }
    if (isClosed) return;
    // Unchanged semantics, deliberately: this counts ARRIVALS (a body came
    // back), not merges and not attempts. `live_tracking_lifecycle_test.dart`
    // and `tracking_live_position_overlay_test.dart` both pin it, and the diag
    // record below is what carries the attempt/merge distinction now.
    if (overlay != null) _positionReadCount++;
    final applied = _applyLivePosition(overlay);
    Diag.event(kTrackingPositionEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'cause': cause.wire,
      'applied': applied,
      'lat': overlay?.jeeberPosition?.lat,
      'lng': overlay?.jeeberPosition?.lng,
      'polyline': overlay?.polyline.length ?? 0,
      'stale': overlay?.stale,
      // Null-aware ELEMENT: the key is absent entirely on the happy path, so a
      // capture parser can treat the mere PRESENCE of `error` as the signal
      // rather than having to distinguish null from absent.
      'error': ?failure,
    });
    // Drain the coalesced cause, if any. Cleared BEFORE the recursive call so a
    // cause arriving during the drain re-fills the slot instead of being
    // swallowed, and so this can never loop without a new external event.
    final pending = _pendingPositionCause;
    if (pending == null) return;
    _pendingPositionCause = null;
    await _readLivePosition(pending);
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
  ///
  /// Returns whether the overlay actually LANDED on the snapshot — the `applied`
  /// field of [kTrackingPositionEvent]. MB1's MARKER leg counts distinct
  /// `(lat,lng)` pairs among the `applied:true` records only, because a merge
  /// that was dropped (empty overlay, or no row to merge onto yet) never reached
  /// the map and must not be counted as a marker that moved.
  bool _applyLivePosition(DeliveryLivePosition? overlay) {
    if (overlay == null || isClosed || overlay.isEmpty) return false;
    final current = state.trackingInfo;
    if (current == null) return false;
    emit(state.copyWith(
      trackingInfo: current.withLivePosition(
        jeeberPosition: overlay.jeeberPosition,
        polyline: overlay.polyline,
        stale: overlay.stale,
        secondsSinceUpdate: overlay.secondsSinceUpdate,
      ),
    ));
    return true;
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
  /// The position axis is still READ inside [_fetch], on the same events — so
  /// there is nothing here to re-arm and no timer to leak. The optional
  /// subscription added alongside it is armed exactly once (see
  /// [_positionStreamArmed]) and is not a watcher that re-arms.
  void _armWatchers() {
    if (isClosed) return;
    if (_isTerminal) {
      _retireWatchers();
      return;
    }
    _refreshSubscription ??= _refreshSignals?.listen((_) => _refreshFromPush());
    unawaited(_armPositionStream());
  }

  /// Open the courier-position subscription, at most once per screen entry.
  ///
  /// Total by construction. A channel that returns null, throws, or hands back
  /// a stream that immediately dies must all produce the same outcome: this
  /// screen keeps its four read triggers and nothing else changes. `open()` is
  /// documented to return null rather than throw, but a devtool double or a
  /// future implementation is not bound by that doc comment, and an error
  /// escaping an `unawaited` call rides out as an unhandled zone error.
  ///
  /// Called from [_armWatchers], i.e. after the first [_fetch] has landed a row
  /// — which matters: [_applyLivePosition] merges ONTO `state.trackingInfo` and
  /// drops the overlay when there is nothing to merge onto. Arming before the
  /// first status read would silently discard the earliest fixes.
  Future<void> _armPositionStream() async {
    final channel = _positionChannel;
    if (channel == null) return;
    if (_positionStreamArmed || isClosed || _isTerminal) return;
    _positionStreamArmed = true;
    Stream<CourierPositionFix>? positions;
    try {
      positions = await channel.open(deliveryId: deliveryId);
    } catch (_) {
      positions = null;
    }
    if (positions == null) return;
    if (isClosed || _isTerminal) {
      // Raced with teardown. Cancel immediately rather than leaving an open
      // socket behind a closed screen — cancelling is what closes it.
      unawaited(positions.listen(null).cancel());
      return;
    }
    _streamedPositionLeg = positions.listen(
      _onStreamedPosition,
      // An error is a death, not a state the screen renders. The leg simply
      // ends and the four triggers carry on.
      onError: (Object _, StackTrace _) => _retirePositionStream(),
      onDone: _retirePositionStream,
      cancelOnError: false,
    );
  }

  /// One arrived position → one marker move.
  ///
  /// Reuses [_applyLivePosition] rather than emitting directly, so the three
  /// merge invariants documented there (no `pendingEvent` re-fire, empty
  /// overlays dropped, nothing merged before there is a row) hold for the
  /// subscription exactly as they do for the snapshot read — one merge path,
  /// not two that can drift.
  ///
  /// `stale: false` and `secondsSinceUpdate: 0` are FACTS here, not optimism:
  /// the gateway publishes this frame from the ingest of the courier's own
  /// upload, so its age is the flight time of one WebSocket frame. That is the
  /// whole difference between a pushed fix and the snapshot route's, where the
  /// gateway's own `stale` verdict has to be carried because the fix may be
  /// minutes old.
  void _onStreamedPosition(CourierPositionFix fix) {
    if (isClosed || _isTerminal) return;
    _streamedPositionCount++;
    final applied = _applyLivePosition(DeliveryLivePosition(
      jeeberPosition: GpsPoint(lat: fix.lat, lng: fix.lng),
      stale: false,
      secondsSinceUpdate: 0,
    ));
    Diag.event(kTrackingStreamPositionEvent, <String, Object?>{
      'deliveryId': deliveryId,
      'lat': fix.lat,
      'lng': fix.lng,
      'applied': applied,
      'n': _streamedPositionCount,
    });
  }

  /// Drop the leg. Cancelling it is what closes the underlying socket
  /// (`CourierPositionSocket` wires its controller's `onCancel` to `close()`),
  /// so this is the release, not merely an unhook.
  void _retirePositionStream() {
    unawaited(_streamedPositionLeg?.cancel());
    _streamedPositionLeg = null;
  }

  /// Stop watching. `cancel()`'s future is deliberately NOT awaited: once it
  /// RETURNS no further events are delivered, nulling the field is what makes
  /// that observable, and awaiting a cancel from `close()` deadlocks the
  /// fake-async zone under `testWidgets`.
  void _retireWatchers() {
    unawaited(_refreshSubscription?.cancel());
    _refreshSubscription = null;
    _retirePositionStream();
  }

  void retry() {
    // `emit` after `close()` throws in bloc. Every other entry point on this
    // cubit guards it; this one did not. Pre-existing on `origin/main`, fixed
    // here because this method is in the diff.
    if (isClosed) return;
    emit(state.copyWith(mode: LiveTrackingViewMode.loading, clearError: true));
    _fetchAndSchedule(LivePositionReadCause.retry);
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
      await _fetch(LivePositionReadCause.resume);
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
