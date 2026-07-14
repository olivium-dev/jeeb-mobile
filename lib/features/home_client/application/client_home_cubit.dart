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

  /// F3 (offers-polling storm): while a 429 `Retry-After` window is open, poll
  /// refreshes are skipped so the client stops hammering the throttled gateway.
  /// `null` when we are not backing off. A manual [load] (initial / retry CTA)
  /// bypasses this — only the silent poll/refresh path honors it.
  DateTime? _rateLimitedUntil;

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
    // Honor an open 429 Retry-After window — silently skip this poll/refresh
    // tick rather than pile another read onto the throttled gateway. The
    // already-rendered data stays on screen.
    final backoffUntil = _rateLimitedUntil;
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil)) return;
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

      // F3 (offers-polling storm): a throttled load must degrade gracefully. A
      // 429 must NEVER surface the full-screen "Couldn't reach Jeeb" error and
      // must never blank a working screen back to empty.
      if (snapshot.rateLimited) {
        // Back the poll off for the advertised Retry-After (or one poll cycle).
        _rateLimitedUntil = DateTime.now().add(
          snapshot.retryAfter ?? _pollInterval,
        );
        // Already showing data → keep it verbatim. The partial/empty rows the
        // throttled load returned must not overwrite the good cached lists.
        if (state.status == ClientHomeStatus.ready) return;
        // Cold load got throttled: fall through and paint whatever partial data
        // arrived (often empty) as a normal READY screen — New Order stays
        // reachable, and the retry/poll picks the rest up once the window ends.
      } else {
        // A clean load clears any backoff so polling resumes at full cadence.
        _rateLimitedUntil = null;
      }

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
      // Defence in depth: an unexpected error must not blow away a working
      // screen. Only surface the full-screen connection error on a COLD failure
      // (nothing cached yet) — a failed background refresh keeps prior data.
      if (state.status == ClientHomeStatus.ready) return;
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
