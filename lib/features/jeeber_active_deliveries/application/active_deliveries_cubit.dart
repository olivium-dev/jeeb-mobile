import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
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
    // A reachable `offer_accepted` notification publishes on the shared refresh
    // bus.
    //
    // b02 READ ECONOMICS — through a [DeferredRefreshGate]. The comment that
    // stood here read "the subscription remains independent of polling
    // visibility so a hidden dashboard still refreshes", and that reasoning is
    // what put a `GET /v1/deliveries?role=jeeber` on the wire for a card behind
    // the active-delivery route. The gate keeps the guarantee the comment was
    // protecting — a hidden dashboard is NEVER left stale — while paying for it
    // once, when the dashboard is looked at again, instead of on every push.
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ActiveDeliveriesCubit',
    );
  }

  final ActiveDeliveriesRepository _repository;
  final Duration _pollInterval;
  late final DeferredRefreshGate _refreshGate;
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

  /// Drives BOTH the 60 s safety-net poller and the push-refresh gate, so a
  /// dashboard that is off screen neither polls nor reads on push — and catches
  /// up with exactly one read when it comes back.
  @override
  void setPollingVisible(bool visible) {
    _poller.setPollingVisible(visible);
    _refreshGate.setPollingVisible(visible);
  }

  /// SINGLE FLIGHT (b02 wave D). This cubit has THREE independent triggers —
  /// the 60s poller, the push bus, and the visibility/resume tick — and only
  /// the poller ever coordinated with itself. A jeeber whose offer is accepted
  /// receives `offer_accepted` and, moments later, the first `type=delivery`
  /// transition: two bus events well inside one `GET /v1/deliveries?role=jeeber`
  /// round trip. Overlapping, the later-issued read can complete FIRST and
  /// paint the card from the older snapshot — the accepted delivery flickers,
  /// or briefly disappears. A clock alone could never produce that.
  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (isClosed || _refreshInFlight) return;
    _refreshInFlight = true;
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
    _poller.dispose();
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}
