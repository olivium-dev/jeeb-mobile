import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/lifecycle_poller.dart';
import '../../../core/lifecycle/polling_visibility.dart';
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
class ClientHomeCubit extends Cubit<ClientHomeState>
    implements PollingVisibility {
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
    //
    // b02 READ ECONOMICS — through a [DeferredRefreshGate]. This cubit's snapshot
    // is the app's most expensive single refetch: measured on the real repository
    // over a recording adapter, ONE signal costs SEVEN wire reads (`/deliveries`
    // + `/requests` x2 + one `GET /v1/offers?requestId=` per non-accepted
    // request). It also lives in the shell's `IndexedStack`, so it stays mounted
    // and subscribed while `/delivery/:id` or `/chat/:id` sits on top of the
    // shell — and those seven reads repainted pixels nobody could see. They were
    // the largest term in the TEN reads one `delivery` push produced on the
    // customer phone (`tools/STATE-PROVEN.md:181`, the `/v1/offers` x4 +
    // `/requests` x2 duplicate pattern).
    //
    // The gate DEFERS rather than drops: the debt is paid once on the way back to
    // visible, so no user-visible state is ever stale. With no visibility driver
    // (a bare widget test, a fixture host) the gate defaults to visible and this
    // is byte-for-byte the previous behaviour.
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ClientHomeCubit',
    );
  }

  final ClientHomeRepository _repository;
  final String? Function() _greetingNameProvider;
  late final DeferredRefreshGate _refreshGate;

  /// Poll cadence while the In Progress tab is visible. Mirrors
  /// ActiveDeliveriesCubit's 10s cadence so a status change (jeeber accepted /
  /// picked / delivered / cancelled) surfaces on the customer's In Progress
  /// list within seconds without a manual pull-to-refresh.
  final Duration _pollInterval;
  late final LifecyclePoller _poller = LifecyclePoller(
    interval: _pollInterval,
    onTick: refresh,
    debugLabel: 'ClientHomeCubit',
  );

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
  /// SINGLE FLIGHT (b02 wave D). Two triggers landing inside one round trip
  /// must produce ONE re-pull, not two overlapping ones whose emits race — the
  /// later request can complete first and paint the OLDER snapshot.
  ///
  /// This guard did not exist while only a clock drove the surface, and it did
  /// not need to: `LifecyclePoller` fires one tick at a time and skips a tick
  /// while the previous one is outstanding. It became necessary when the push
  /// bus joined the poll as a second, independently-timed trigger — and wave D
  /// made the arrival rate on that bus a property of the gateway rather than of
  /// a clock, so bursts (a bid plus the accept, two transitions in a row) are
  /// ordinary. Note that `state.status == loading` was never this guard:
  /// [refresh] is the SILENT path and deliberately never sets `loading`, so it
  /// could not see itself.
  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (state.status == ClientHomeStatus.loading) return;
    if (_refreshInFlight) return;
    // Honor an open 429 Retry-After window — silently skip this poll/refresh
    // tick rather than pile another read onto the throttled gateway. The
    // already-rendered data stays on screen.
    final backoffUntil = _rateLimitedUntil;
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil)) return;
    _refreshInFlight = true;
    try {
      await _fetch();
    } finally {
      _refreshInFlight = false;
    }
  }

  /// Start the 10s live-refresh poll. Called by the screen when the In Progress
  /// tab becomes visible. Idempotent — a second call is a no-op so re-entering
  /// the tab never double-schedules. The poll uses [refresh] (silent), so it
  /// never flashes the loading spinner over already-rendered data.
  void startPolling() => _poller.start();

  /// Stop the poll. Called when the In Progress tab is hidden or the screen is
  /// disposed. Idempotent.
  void stopPolling() => _poller.stop();

  /// Surface visibility — shell-tab selection AND route-on-top, ANDed by the host
  /// (`shell/tabs/home_tab.dart`).
  ///
  /// Drives BOTH latches, and both are load-bearing:
  ///
  ///   * the push-refresh gate — the seven-read snapshot is deferred while the
  ///     surface is off screen, and paid once on return;
  ///   * the 10 s poller's own `visible` latch — `_syncPolling` in
  ///     `client_home_screen.dart` ANDs tab + sub-tab + foreground, but it has
  ///     never known about ROUTES. With `/delivery/:id` pushed on top of the
  ///     shell the In-Progress poll kept ticking at full cadence against an
  ///     invisible screen. `LifecyclePoller` keeps `visible` independent of
  ///     `started`, so this can neither resurrect a poller its owner stopped nor
  ///     start one that was never started.
  ///
  /// Level-triggered and idempotent, so the many rebuilds
  /// `didChangeDependencies` produces cost nothing.
  @override
  void setPollingVisible(bool visible) {
    _poller.setPollingVisible(visible);
    _refreshGate.setPollingVisible(visible);
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
    _poller.dispose();
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}
