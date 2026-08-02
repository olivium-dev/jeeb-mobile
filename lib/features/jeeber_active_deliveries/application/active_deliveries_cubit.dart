import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

enum ActiveDeliveriesPhase { loading, loaded }

class ActiveDeliveriesState extends Equatable {
  const ActiveDeliveriesState({
    this.phase = ActiveDeliveriesPhase.loading,
    this.deliveries = const <ActiveDeliverySummary>[],
  });

  final ActiveDeliveriesPhase phase;
  final List<ActiveDeliverySummary> deliveries;

  bool get hasDeliveries => deliveries.isNotEmpty;

  ActiveDeliveriesState copyWith({
    ActiveDeliveriesPhase? phase,
    List<ActiveDeliverySummary>? deliveries,
  }) => ActiveDeliveriesState(
    phase: phase ?? this.phase,
    deliveries: deliveries ?? this.deliveries,
  );

  @override
  List<Object?> get props => [phase, deliveries];
}

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
