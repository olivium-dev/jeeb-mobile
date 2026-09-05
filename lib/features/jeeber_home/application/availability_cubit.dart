import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
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
    Stream<void>? resumeSignals,
  })  : _gateway = gateway,
        _policy = policy,
        _clock = clock ?? DateTime.now,
        _tickerFactory = tickerFactory ?? _defaultTickerFactory,
        super(const AvailabilityViewState()) {
    _resumeSub = resumeSignals?.listen(
      (_) => unawaited(refreshLocationOnResume()),
    );
  }

  final AvailabilityGateway _gateway;
  final AvailabilityInactivityPolicy _policy;
  final DateTime Function() _clock;
  final Stream<DateTime> Function() _tickerFactory;

  StreamSubscription<DateTime>? _idleTicker;
  StreamSubscription<void>? _resumeSub;

  bool _locationRefreshInFlight = false;

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
    } on AvailabilityGatewayException catch (e) {
      emit(e.notRegistered
          ? state.copyWith(
              loadPhase: AvailabilityLoadPhase.notRegistered,
              loadError: null,
            )
          : state.copyWith(
              loadPhase: AvailabilityLoadPhase.loadError,
              loadError: e.failure ?? AppFailure.of(e),
            ));
    } catch (e) {
      // JHOME-04: a parse TypeError would otherwise pin the home on loading.
      emit(state.copyWith(
        loadPhase: AvailabilityLoadPhase.loadError,
        loadError: AppFailure.of(e),
      ));
    }
  }

  Future<void> toggle() async {
    if (state.isToggleInFlight) return;
    final goOnline = !state.status.isOnline;
    emit(state.copyWith(
      isToggleInFlight: true,
      toggleError: false,
      toggleFailure: null,
    ));
    try {
      final result = await _gateway.toggle(goOnline: goOnline);
      emit(state.copyWith(
        isToggleInFlight: false,
        status: result.status,
        warningVisible: false,
        locationOutcome: goOnline
            ? result.location
            : GoOnlineLocationOutcome.notApplicable,
      ));
      _restartIdleTickerIfOnline();
    } on AvailabilityGatewayException catch (e) {
      emit(state.copyWith(
        isToggleInFlight: false,
        toggleError: true,
        toggleFailure: e.failure ?? AppFailure.of(e),
      ));
    } catch (e) {
      // Without this the toggle stays in-flight forever on a parse error.
      emit(state.copyWith(
        isToggleInFlight: false,
        toggleError: true,
        toggleFailure: AppFailure.of(e),
      ));
    }
  }

  /// Re-stamps server-side last_location on foreground so an idle-online
  /// jeeber stays visible to new-request fan-out without any polling.
  Future<void> refreshLocationOnResume() async {
    if (isClosed ||
        !state.status.isOnline ||
        state.isToggleInFlight ||
        _locationRefreshInFlight) {
      return;
    }
    _locationRefreshInFlight = true;
    try {
      final snapshot = await _gateway.fetch();
      if (isClosed) return;
      emit(state.copyWith(status: snapshot));
      // Server may have auto-offlined us; refreshing would silently resurrect.
      if (!snapshot.isOnline) return;
      await _gateway.refreshLocation();
    } on AvailabilityGatewayException {
      // Best-effort: a failed resume refresh must not surface an error.
    } catch (_) {
      // Same contract for an untyped failure — silent by design.
    } finally {
      _locationRefreshInFlight = false;
    }
  }

  Future<void> retryLocationAttach() async {
    if (!state.status.isOnline) return;
    emit(state.copyWith(
      locationOutcome: GoOnlineLocationOutcome.notApplicable,
    ));
    try {
      final outcome = await _gateway.refreshLocation();
      if (!isClosed) emit(state.copyWith(locationOutcome: outcome));
    } on AvailabilityGatewayException {
      if (!isClosed) {
        emit(state.copyWith(locationOutcome: GoOnlineLocationOutcome.fixFailed));
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(locationOutcome: GoOnlineLocationOutcome.fixFailed));
      }
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
    _resumeSub?.cancel();
    _resumeSub = null;
    return super.close();
  }
}
