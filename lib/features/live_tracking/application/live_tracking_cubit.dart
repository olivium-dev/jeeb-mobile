import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  Timer? _pollTimer;

  Future<void> _fetchAndSchedule() async {
    await Future.wait([_hydrateHandoverCode(), _fetch()]);
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
        // sprint-009 scenario matrix #9: a cancelled/expired delivery is
        // terminal — stop polling a dead row (the screen renders the graceful
        // terminal state instead of a live stepper).
        if (info.isCancelled) {
          _pollTimer?.cancel();
          _pollTimer = null;
        }
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

  void _schedulePoll() {
    _pollTimer?.cancel();
    // Never (re)arm the poll for a terminal cancelled delivery — the first
    // fetch may already have read the terminal row (scenario matrix #9).
    if (state.trackingInfo?.isCancelled ?? false) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  void retry() {
    emit(state.copyWith(mode: LiveTrackingViewMode.loading, clearError: true));
    _fetchAndSchedule();
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
    _pollTimer?.cancel();
    return super.close();
  }
}
