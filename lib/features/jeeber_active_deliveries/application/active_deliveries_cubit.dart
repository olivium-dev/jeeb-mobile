import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../../../core/network/app_failure.dart';
import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

enum ActiveDeliveriesPhase { loading, loaded, failed }

class ActiveDeliveriesState extends Equatable {
  const ActiveDeliveriesState({
    this.phase = ActiveDeliveriesPhase.loading,
    this.deliveries = const <ActiveDeliverySummary>[],
    this.error,
    this.refreshError,
  });

  final ActiveDeliveriesPhase phase;
  final List<ActiveDeliverySummary> deliveries;

  /// Cold failure: the read failed with no cards to keep.
  final AppFailure? error;

  /// Warm failure: cards are on screen and a refresh failed.
  final AppFailure? refreshError;

  bool get hasDeliveries => deliveries.isNotEmpty;

  ActiveDeliveriesState copyWith({
    ActiveDeliveriesPhase? phase,
    List<ActiveDeliverySummary>? deliveries,
    Object? error = _sentinel,
    Object? refreshError = _sentinel,
  }) => ActiveDeliveriesState(
    phase: phase ?? this.phase,
    deliveries: deliveries ?? this.deliveries,
    error: identical(error, _sentinel) ? this.error : error as AppFailure?,
    refreshError: identical(refreshError, _sentinel)
        ? this.refreshError
        : refreshError as AppFailure?,
  );

  @override
  List<Object?> get props => [phase, deliveries, error, refreshError];
}

const Object _sentinel = Object();

class ActiveDeliveriesCubit extends Cubit<ActiveDeliveriesState>
    implements PollingVisibility {
  ActiveDeliveriesCubit({
    required ActiveDeliveriesRepository repository,
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       super(const ActiveDeliveriesState()) {
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ActiveDeliveriesCubit',
    );
  }

  final ActiveDeliveriesRepository _repository;
  late final DeferredRefreshGate _refreshGate;

  bool _started = false;

  @visibleForTesting
  bool get debugStarted => _started;

  @visibleForTesting
  int get debugRefreshCount => _refreshCount;
  int _refreshCount = 0;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
  }

  void refreshOnResume() => _refreshGate.signal();

  @override
  void setPollingVisible(bool visible) =>
      _refreshGate.setPollingVisible(visible);

  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (isClosed || _refreshInFlight) return;
    _refreshInFlight = true;
    _refreshCount++;
    try {
      final deliveries = await _repository.listActive();
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: ActiveDeliveriesPhase.loaded,
          deliveries: deliveries,
          error: null,
          refreshError: null,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailure.of(e);
      // Warm failure keeps the last-good cards; only a cold one goes dark.
      emit(
        state.deliveries.isEmpty
            ? state.copyWith(
                phase: ActiveDeliveriesPhase.failed,
                error: failure,
                refreshError: null,
              )
            : state.copyWith(
                phase: ActiveDeliveriesPhase.loaded,
                refreshError: failure,
              ),
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  Future<void> close() {
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}
