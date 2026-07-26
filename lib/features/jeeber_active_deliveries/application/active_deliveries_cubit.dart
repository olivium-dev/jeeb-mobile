import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/lifecycle_poller.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

const Duration kActiveDeliveriesSafetyNetPollInterval = Duration(seconds: 60);

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
  }) => ActiveDeliveriesState(
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
/// poll is cheap and never blocks the feed. A 60s safety-net poll catches a
/// missed notification without keeping the former 10s foreground cadence.
///
/// When [refreshSignals] is wired, a reachable `offer_accepted` notification
/// re-pulls this surface immediately. Delivery-status notifications do not
/// reach this bus: their gateway transport and mobile payload path are inert.
/// See `JEBV4-NEW-P1-delivery-status-push-inert.md`.
class ActiveDeliveriesCubit extends Cubit<ActiveDeliveriesState>
    implements PollingVisibility {
  ActiveDeliveriesCubit({
    required ActiveDeliveriesRepository repository,
    Duration pollInterval = kActiveDeliveriesSafetyNetPollInterval,
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       _pollInterval = pollInterval,
       super(const ActiveDeliveriesState()) {
    // A reachable `offer_accepted` notification publishes on the shared
    // refresh bus. Delivery-status notifications do not; see
    // `JEBV4-NEW-P1-delivery-status-push-inert.md`. The subscription remains
    // independent of polling visibility so a hidden dashboard still refreshes.
    if (refreshSignals != null) {
      _refreshSub = refreshSignals.listen((_) => unawaited(refresh()));
    }
  }

  final ActiveDeliveriesRepository _repository;
  final Duration _pollInterval;
  StreamSubscription<void>? _refreshSub;
  late final LifecyclePoller _poller = LifecyclePoller(
    interval: _pollInterval,
    onTick: refresh,
    tickOnResume: true,
    debugLabel: 'ActiveDeliveriesCubit',
  );

  @visibleForTesting
  LifecyclePoller get debugPoller => _poller;

  /// Begin loading + polling. Idempotent — a second call is a no-op so the
  /// dashboard can `..start()` at create-time without double-scheduling.
  void start() {
    if (_poller.isStarted) return;
    unawaited(refresh());
    _poller.start();
  }

  @override
  void setPollingVisible(bool visible) => _poller.setPollingVisible(visible);

  Future<void> refresh() async {
    final deliveries = await _repository.listActive();
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: ActiveDeliveriesPhase.loaded,
        deliveries: deliveries,
      ),
    );
  }

  @override
  Future<void> close() {
    _poller.dispose();
    _refreshSub?.cancel();
    return super.close();
  }
}
