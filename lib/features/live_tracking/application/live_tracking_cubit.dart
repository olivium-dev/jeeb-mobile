import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';
import 'live_tracking_state.dart';

class LiveTrackingCubit extends Cubit<LiveTrackingState> {
  LiveTrackingCubit({
    required LiveTrackingRepository repository,
    required this.deliveryId,
    Duration pollInterval = const Duration(seconds: 5),
  })  : _repository = repository,
        _pollInterval = pollInterval,
        super(const LiveTrackingState()) {
    _fetchAndSchedule();
  }

  final LiveTrackingRepository _repository;
  final String deliveryId;
  final Duration _pollInterval;
  Timer? _pollTimer;

  Future<void> _fetchAndSchedule() async {
    await _fetch();
    _schedulePoll();
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
      }
    } on LiveTrackingException catch (e) {
      if (!isClosed) {
        if (state.trackingInfo == null) {
          emit(state.copyWith(
            mode: LiveTrackingViewMode.error,
            errorMessage: _mapError(e.kind),
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
      case LiveTrackingErrorKind.parse:
        return 'Unexpected response format.';
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
