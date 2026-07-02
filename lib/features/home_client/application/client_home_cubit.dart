import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/client_home_repository.dart';
import 'client_home_state.dart';

/// Owns the client home tab's load + refresh lifecycle.
///
/// Inputs:
///   - [ClientHomeRepository] — talks to jeeb-gateway's home-summary endpoint.
///   - [greetingNameProvider] — injected by DI so tests can pass a fixed
///     name without spinning up the auth-session cubit.
///
/// The cubit deliberately holds only display state. It does NOT own the
/// active-request stream — that's the tracking cubit's job (T-mobile-014).
/// On a successful tracking-state push, the calling shell triggers
/// [refresh] to re-pull the summary.
class ClientHomeCubit extends Cubit<ClientHomeState> {
  ClientHomeCubit({
    required ClientHomeRepository repository,
    required String? Function() greetingNameProvider,
    Duration pollInterval = const Duration(seconds: 10),
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       _greetingNameProvider = greetingNameProvider,
       _pollInterval = pollInterval,
       super(const ClientHomeState()) {
    // Push-triggered refetch: a status-change push (PushRefreshSignals) re-pulls
    // the summary immediately, so a status change surfaces without waiting for
    // the 10s poll tick. Silent refresh — keeps the current data painted.
    if (refreshSignals != null) {
      _refreshSignalSub = refreshSignals.listen((_) => unawaited(refresh()));
    }
  }

  final ClientHomeRepository _repository;
  final String? Function() _greetingNameProvider;
  StreamSubscription<void>? _refreshSignalSub;

  /// Poll cadence while the In Progress tab is visible. Mirrors
  /// ActiveDeliveriesCubit's 10s cadence so a status change (jeeber accepted /
  /// picked / delivered / cancelled) surfaces on the customer's In Progress
  /// list within seconds without a manual pull-to-refresh.
  final Duration _pollInterval;
  Timer? _pollTimer;

  /// Initial load. Safe to call from `initState` — re-entrant calls while
  /// a load is in flight are dropped on the floor.
  Future<void> load() async {
    if (state.status == ClientHomeStatus.loading) return;
    emit(
      state.copyWith(
        status: ClientHomeStatus.loading,
        greetingName: _greetingNameProvider(),
      ),
    );
    await _fetch();
  }

  /// Triggered by pull-to-refresh + the post-action handlers (e.g. after a
  /// new request is created or one finishes). Keeps the previously-rendered
  /// data visible while the network call is in flight to avoid a jarring
  /// empty flash.
  Future<void> refresh() async {
    if (state.status == ClientHomeStatus.loading) return;
    await _fetch();
  }

  /// Start the 10s live-refresh poll. Called by the screen when the In Progress
  /// tab becomes visible. Idempotent — a second call is a no-op so re-entering
  /// the tab never double-schedules. The poll uses [refresh] (silent), so it
  /// never flashes the loading spinner over already-rendered data.
  void startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  /// Stop the poll. Called when the In Progress tab is hidden or the screen is
  /// disposed. Idempotent.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetch() async {
    try {
      final snapshot = await _repository.loadSnapshot();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ClientHomeStatus.ready,
          inProgress: snapshot.inProgress,
          pending: snapshot.pending,
          replies: snapshot.replies,
          // Cap the "Order again" strip at one entry — anything more belongs
          // on the Orders tab, not the home summary.
          recentDeliveries: snapshot.recentDeliveries.take(1).toList(),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(status: ClientHomeStatus.failed));
    }
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    unawaited(_refreshSignalSub?.cancel());
    return super.close();
  }
}
