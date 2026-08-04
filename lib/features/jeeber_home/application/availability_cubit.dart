import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/availability_inactivity_policy.dart';
import '../domain/entities/availability_status.dart';
import '../domain/services/availability_gateway.dart';
import 'availability_state.dart';

class AvailabilityCubit extends Cubit<AvailabilityViewState> {
  AvailabilityCubit({
    required AvailabilityGateway gateway,
    AvailabilityInactivityPolicy policy = const AvailabilityInactivityPolicy(),
    DateTime Function()? clock,
    Stream<DateTime> Function()? tickerFactory,
  })  : _gateway = gateway,
        _policy = policy,
        _clock = clock ?? DateTime.now,
        _tickerFactory = tickerFactory ?? _defaultTickerFactory,
        super(const AvailabilityViewState());

  final AvailabilityGateway _gateway;
  final AvailabilityInactivityPolicy _policy;
  final DateTime Function() _clock;
  final Stream<DateTime> Function() _tickerFactory;

  StreamSubscription<DateTime>? _idleTicker;

  static Stream<DateTime> _defaultTickerFactory() =>
      Stream<DateTime>.periodic(
        const Duration(minutes: 1),
        (_) => DateTime.now(),
      );

  AvailabilityInactivityPolicy get policy => _policy;

  Future<void> load() async {
    if (state.loadPhase == AvailabilityLoadPhase.loading) return;
    emit(state.copyWith(loadPhase: AvailabilityLoadPhase.loading));
    try {
      final snapshot = await _gateway.fetch();
      emit(state.copyWith(
        loadPhase: AvailabilityLoadPhase.ready,
        status: snapshot,
      ));
      _restartIdleTickerIfOnline();
    } on AvailabilityGatewayException {
      emit(state.copyWith(loadPhase: AvailabilityLoadPhase.loadError));
    }
  }

  Future<void> toggle() async {
    if (state.isToggleInFlight) return;
    final goOnline = !state.status.isOnline;
    emit(state.copyWith(isToggleInFlight: true, toggleError: false));
    try {
      final snapshot = await _gateway.toggle(goOnline: goOnline);
      emit(state.copyWith(
        isToggleInFlight: false,
        status: snapshot,
        warningVisible: false,
      ));
      _restartIdleTickerIfOnline();
    } on AvailabilityGatewayException {
      emit(state.copyWith(isToggleInFlight: false, toggleError: true));
    }
  }

  void extendActivity() {
    if (!state.status.isOnline) return;
    final now = _clock();
    emit(state.copyWith(
      status: state.status.copyWith(lastActivityAt: now),
      warningVisible: false,
    ));
    _restartIdleTickerIfOnline();
  }

  void _restartIdleTickerIfOnline() {
    _idleTicker?.cancel();
    _idleTicker = null;
    if (!state.status.isOnline) return;
    _idleTicker = _tickerFactory().listen((_) => _onIdleTick());
  }

  void _onIdleTick() {
    final last = state.status.lastActivityAt;
    if (last == null || !state.status.isOnline) return;
    final elapsed = _clock().difference(last);
    if (_policy.shouldAutoOffline(elapsed)) {
      _idleTicker?.cancel();
      _idleTicker = null;
      emit(state.copyWith(
        status: state.status.copyWith(state: AvailabilityState.autoOffline),
        warningVisible: false,
      ));
      return;
    }
    final warn = _policy.shouldWarn(elapsed);
    if (warn != state.warningVisible) {
      emit(state.copyWith(warningVisible: warn));
    }
  }

  @override
  Future<void> close() {
    _idleTicker?.cancel();
    _idleTicker = null;
    return super.close();
  }
}
