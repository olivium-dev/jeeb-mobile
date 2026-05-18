import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

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
