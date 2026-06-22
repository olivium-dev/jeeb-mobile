import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

/// Load phase for the jeeber active-deliveries banner.
enum ActiveDeliveriesPhase { loading, loaded }

/// State emitted by [ActiveDeliveriesCubit].
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
  }) =>
      ActiveDeliveriesState(
        phase: phase ?? this.phase,
        deliveries: deliveries ?? this.deliveries,
      );

  @override
  List<Object?> get props => [phase, deliveries];
}

/// Drives the jeeber's "active deliveries" surface (iter6 real-flow blocker
/// fix). Loads the accepted/assigned deliveries from
/// `GET /v1/deliveries?role=jeeber` and re-polls so a freshly-accepted offer
/// surfaces without the jeeber having to leave + return to the dashboard.
///
/// The banner is empty (hidden) when the jeeber has no active delivery, so the
/// poll is cheap and never blocks the feed. The poll mirrors the request-feed
/// cadence (10s) — short enough that the jeeber sees the accepted order within
/// seconds of the client tapping Accept, the exact window the prior blocker
/// stranded them in.
class ActiveDeliveriesCubit extends Cubit<ActiveDeliveriesState> {
  ActiveDeliveriesCubit({
    required ActiveDeliveriesRepository repository,
    Duration pollInterval = const Duration(seconds: 10),
  })  : _repository = repository,
        _pollInterval = pollInterval,
        super(const ActiveDeliveriesState());

  final ActiveDeliveriesRepository _repository;
  final Duration _pollInterval;
  Timer? _pollTimer;

  /// Begin loading + polling. Idempotent — a second call is a no-op so the
  /// dashboard can `..start()` at create-time without double-scheduling.
  void start() {
    if (_pollTimer != null) return;
    unawaited(refresh());
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final deliveries = await _repository.listActive();
    if (isClosed) return;
    emit(state.copyWith(
      phase: ActiveDeliveriesPhase.loaded,
      deliveries: deliveries,
    ));
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
