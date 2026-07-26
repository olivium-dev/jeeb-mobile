import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/lifecycle_poller.dart';
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'live_tracking_state.dart';

class LiveTrackingCubit extends Cubit<LiveTrackingState> {
  LiveTrackingCubit({
    required LiveTrackingRepository repository,
    required this.deliveryId,
    Duration pollInterval = const Duration(seconds: 5),
    HandoverCodeStore? handoverCodeStore,
  })  : _repository = repository,
        _pollInterval = pollInterval,
        _handoverCodeStore = handoverCodeStore,
        super(const LiveTrackingState()) {
    _fetchAndSchedule();
  }

  final LiveTrackingRepository _repository;
  final String deliveryId;
  final Duration _pollInterval;

  /// G4: local, restart-safe source of the delivery hand-over code (persisted
  /// at offer-accept time). Read-only here — the tracking surface renders it
  /// discoverably pre-at-door and prominently at the door. It deliberately
  /// NEVER calls `GET /otp` (that endpoint is an SMS trigger on the live
  /// gateway — polling it would spam the recipient with texts).
  final HandoverCodeStore? _handoverCodeStore;
  late final LifecyclePoller _poller = LifecyclePoller(
    interval: _pollInterval,
    onTick: _poll,
    tickOnResume: false,
    debugLabel: 'LiveTrackingCubit',
  );

  @visibleForTesting
  LifecyclePoller get debugPoller => _poller;

  /// Nothing more is worth polling for. Two INDEPENDENT axes, deliberately:
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
    _armPoll();
  }

  Future<void> _poll() async {
    await _fetch();
    _schedulePoll();
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
        // expired delivery is terminal — stop polling a dead row (the screen
        // renders the graceful terminal state instead of a live stepper). A
        // `failed` (FailedNeedsEscalation) row KEEPS polling: an admin can
        // still resolve it to Done or cancel it, so it is not poll-terminal.
        // `stop()` is STICKY — no resume or visibility change re-arms it.
        if (_isTerminal) _poller.stop();
      }
      // JEBV4-269: overlay the jeeber's live GPS position + route onto the
      // stage/summary snapshot so the map marker moves. Best-effort + AFTER the
      // stage emit so a missing/late position never delays or faults the
      // stepper.
      await _overlayLivePosition(info);
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

  /// JEBV4-269: best-effort live-position overlay. When the repository can
  /// supply GPS ([LivePositionSource]) and the delivery is still live, read the
  /// latest Jeeber position + route from the gateway tracking snapshot and merge
  /// it onto the current [DeliveryTrackingInfo]. A null/empty overlay, a closed
  /// cubit, or a repo that doesn't provide positions is a silent no-op — the
  /// stepper snapshot already emitted stands. The merge emit carries no
  /// `pendingEvent` (copyWith resets it to `none`), so it never re-fires the
  /// at-door / delivered navigation.
  Future<void> _overlayLivePosition(DeliveryTrackingInfo info) async {
    final repo = _repository;
    if (repo is! LivePositionSource) return;
    final source = repo as LivePositionSource;
    // No moving jeeber to plot on a terminal or admin-parked row (P6/A1).
    if (info.isPollTerminal || info.isUnderReview || info.isDelivered) return;
    final DeliveryLivePosition? overlay =
        await source.fetchLivePosition(deliveryId: deliveryId);
    if (isClosed || overlay == null || overlay.isEmpty) return;
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

  void _armPoll() {
    if (_isTerminal) {
      _poller.stop();
      return;
    }
    _poller.start();
  }

  void _schedulePoll() {
    // Never (re)arm the poll for a delivered, cancelled or expired delivery —
    // the first fetch may already have read the terminal row (scenario matrix
    // #9). An escalated `failed` row is NOT poll-terminal and keeps polling
    // (P6/A1).
    if (_isTerminal) {
      _poller.stop();
      return;
    }
    _poller.restart();
  }

  void retry() {
    emit(state.copyWith(mode: LiveTrackingViewMode.loading, clearError: true));
    _fetchAndSchedule();
  }

  /// JEBV4-282: force an immediate re-fetch + re-arm the poll. The screen wires
  /// this to app-resume so a status advanced while the app was backgrounded
  /// (Dart timers are suspended there) surfaces on return instead of waiting up
  /// to one poll interval — or forever, if the OS dropped the timer. Silent (no
  /// loading flash): [_fetch] keeps the last good `trackingInfo` on a failure,
  /// and a delivered/cancelled/expired row is left untouched (nothing more to
  /// poll). An escalated `failed` row still refreshes — admin resolution must
  /// land (P6/A1).
  Future<void> refreshNow() async {
    if (isClosed) return;
    if (_isTerminal) return;
    await _fetch();
    if (!isClosed) _armPoll();
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
    _poller.dispose();
    return super.close();
  }
}
