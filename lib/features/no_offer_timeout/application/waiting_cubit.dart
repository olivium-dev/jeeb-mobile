import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';
import 'waiting_state.dart';

/// Drives the JM-026 waiting / no-coverage screen.
///
/// Responsibilities (mirrors `ClientOffersCubit`, T-mobile-015 pattern):
///  - Cold-load the pre-accept request snapshot (notified count, anchor pair)
///  - Re-read on a PUSH so freshly-arrived offers flip the screen to the review
///    CTA live (AC2) and an expiry/tier-expansion surfaces, without a manual
///    refresh (b02 wave C / N9 — see [refreshSignals])
///  - Drive the countdown via an injected clock against the snapshot's
///    server-anchored deadline — the cubit NEVER invents a window (P7)
///
/// The cubit injects its own clock (`now`) and the countdown tick stream so
/// widget tests can fast-forward time deterministically (no real wall-clock
/// timers leak into the test binding).
class WaitingCubit extends Cubit<WaitingState> {
  WaitingCubit({
    required WaitingRepository repository,
    required String requestId,
    DateTime Function()? now,
    Duration tickInterval = const Duration(seconds: 1),
    Stream<void>? clockTicks,
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       _requestId = requestId,
       _now = now ?? DateTime.now,
       _tickInterval = tickInterval,
       _externalClockTicks = clockTicks,
       _refreshSignals = refreshSignals,
       super(const WaitingState());

  final WaitingRepository _repository;
  final String _requestId;
  final DateTime Function() _now;
  final Duration _tickInterval;
  final Stream<void>? _externalClockTicks;

  /// b02 wave C — N9. Payload-less push→refetch bus; every event is ONE re-read
  /// and there is no cadence behind it.
  ///
  /// This REPLACED an UNGATED 5s `Stream.periodic`, and
  /// [WaitingRepository.fetchWaiting] fans ONE call into TWO gateway reads
  /// (`dio_waiting_repository.dart:49` → `:70` `GET /v1/requests/{id}` and →
  /// `:87` `GET /v1/offers?requestId`), so a single tick was two wire calls.
  ///
  /// TWO already-emitted gateway pushes cover everything that poll watched for,
  /// and both land on this one bus:
  ///  * `type=offer` — a bid arrived; flip to the review-offers CTA (AC2).
  ///    `Notifications/OfferPushNotifier.cs:227`, sent to `request.ClientId`.
  ///  * `type=request_expired` / `type=try_expand_tier` — the request timed out
  ///    or is expanding tier. `Requests/DispatchingRequestExpiryNotifier.cs:112`.
  ///    Both stamp `requestId` + `request_id`, which is what carries them past
  ///    the id guard in `PushNotificationHandler._maybeSignalStatusChange`
  ///    (category `requestExpired`, in its `orderish` set).
  ///
  /// The bus being payload-less is why no discriminator is needed here: this
  /// cubit re-pulls the ONE request it renders, and the snapshot itself decides
  /// which phase to show.
  ///
  /// NOTE the 1s COUNTDOWN tick ([_externalClockTicks]) is a different thing
  /// entirely and is deliberately untouched: it advances `now` so the countdown
  /// widget rebuilds and issues ZERO gateway reads. Deleting it would break the
  /// UI and save no traffic.
  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _clockSubscription;

  /// True once the push subscription is armed — lets a test assert the wiring
  /// without reaching into the stream.
  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  bool _pollInFlight = false;

  /// Cold-load entry-point. Two-phase so the broadcast-state signature ids paint
  /// as early as possible (JM-026 AC1):
  ///
  ///  1. Read the request row ONLY (status + notifiedCount + anchor pair) and emit
  ///     `loaded` immediately — `waiting_notified_count` / `waiting_countdown`
  ///     (or the no-coverage variant) render the instant the row resolves,
  ///     WITHOUT waiting on the offers GET.
  ///  2. Layer the offers signal (AC2) on asynchronously: enrich the already-
  ///     painted snapshot so it flips live to `waiting_review_offers_cta` if
  ///     offers are already in. A failure here is swallowed (the broadcast
  ///     state stays up) — only a failed request read surfaces the error state.
  ///
  /// Subsequent calls are no-ops so the host route can safely re-invoke on
  /// remount.
  Future<void> load() async {
    if (state.status != WaitingScreenStatus.initial) return;
    emit(
      state.copyWith(
        status: WaitingScreenStatus.loading,
        now: _now(),
        clearError: true,
      ),
    );
    try {
      final request = await _repository.fetchRequest(_requestId);
      if (isClosed) return;
      final observedAt = _now();
      emit(
        state.copyWith(
          status: WaitingScreenStatus.loaded,
          request: request,
          now: observedAt,
          clearError: true,
        ),
      );
      if (request.phase.isTerminal) return;
      _attachStreams();
      // Phase 2 — layer the offers signal without blocking the first paint.
      unawaited(_enrichWithOffers());
    } on WaitingException catch (e) {
      if (isClosed) return;
      if (e.failure == WaitingFailure.contractViolation) {
        await _failContract(e);
        return;
      }
      emit(
        state.copyWith(status: WaitingScreenStatus.failed, error: e.failure),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: WaitingScreenStatus.failed,
          error: WaitingFailure.unknown,
        ),
      );
    }
  }

  /// Best-effort second leg of the cold load: reads the offer count and, if
  /// offers are already in, flips the snapshot to the offers-arrived phase so
  /// `waiting_review_offers_cta` appears (AC2). Never tears down the broadcast
  /// state on failure.
  Future<void> _enrichWithOffers() async {
    final request = state.request;
    if (request == null || request.phase.isTerminal) return;
    try {
      final offerCount = await _repository.fetchOfferCount(
        _requestId,
        fallback: request.offerCount,
      );
      if (isClosed) return;
      final latest = state.request;
      if (latest == null || latest.phase.isTerminal) return;
      if (offerCount <= latest.offerCount) return;
      // `copyWith` cannot re-stamp receivedAt/remainingAtReceipt, so the
      // countdown physically cannot reset to full when an offer lands (T6).
      emit(
        state.copyWith(
          request: latest.copyWith(
            phase: WaitingRequestPhase.offersArrived,
            offerCount: offerCount,
          ),
          now: _now(),
        ),
      );
      // Offers are in — stop watching for them.
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
    } catch (_) {
      /* swallow — broadcast state stays up */
    }
  }

  /// The RESUME one-shot (N9 backstop).
  ///
  /// Driven by `AppResumeSignals` at the widget layer
  /// (`RouteResumeRefetch` in `no_offer_timeout_screen.dart`), NOT by a
  /// lifecycle observer here — one app-wide, coalesced, genuine-resume bus
  /// rather than a per-cubit `didChangeAppLifecycleState`, which is the storm
  /// `AppResumeSignals` exists to cap.
  ///
  /// It exists because the deleted 5 s poll was this screen's implicit
  /// self-heal: a `newOffer` / `request_expired` push that lands while the app
  /// is BACKGROUNDED never reaches the refresh bus (only
  /// `FirebaseMessaging.onMessage` publishes to it), so a user who returns
  /// without tapping the notification would otherwise sit on a permanently
  /// stale "Finding Jeebers" while [tick] keeps the countdown moving — frozen
  /// data that looks live.
  ///
  /// Routed through the same single-flighted [_refreshFromPush] the bus uses,
  /// so a resume landing inside an in-flight read is COALESCED onto it rather
  /// than starting a second, and so the terminal/offers teardown rules apply
  /// identically to both triggers.
  ///
  /// Gated on `loaded`: `initial`/`loading` means the cold [load] is still on
  /// the wire (a second read would be a duplicate, and the screen is showing
  /// its shimmer, not stale data), and `failed` is owned by the error state's
  /// Retry CTA — [_refreshFromPush] would fetch without clearing `failed`, so
  /// it would spend a read to repaint the same error.
  void refreshOnResume() {
    if (isClosed || state.status != WaitingScreenStatus.loaded) return;
    unawaited(_refreshFromPush());
  }

  /// Manual retry from the error state. Resets to initial so [load] re-runs.
  Future<void> retry() async {
    if (isClosed) return;
    await _refreshSubscription?.cancel();
    await _clockSubscription?.cancel();
    _refreshSubscription = null;
    _clockSubscription = null;
    emit(const WaitingState());
    await load();
  }

  /// Advances the cubit's notion of "now" so the countdown rebuilds. Exposed so
  /// widget tests can drive it manually rather than depending on real ticks.
  void tick() {
    if (isClosed || state.isTerminal) return;
    emit(state.copyWith(now: _now()));
  }

  void _attachStreams() {
    // b02 wave C / N9: the ONLY inbound refetch trigger is the push bus. The
    // countdown tick below is NOT a poll — zero gateway reads.
    _refreshSubscription = _refreshSignals?.listen((_) => _refreshFromPush());
    _clockSubscription =
        (_externalClockTicks ?? Stream.periodic(_tickInterval, (_) {})).listen(
          (_) => tick(),
        );
  }

  /// One push → one re-read. Single-flighted so two pushes landing inside one
  /// round trip produce ONE re-pull, not two whose emits race.
  Future<void> _refreshFromPush() async {
    if (isClosed || state.isTerminal || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final request = await _repository.fetchWaiting(_requestId);
      if (isClosed) return;
      final observedAt = _now();
      emit(state.copyWith(request: request, now: observedAt));
      if (request.phase.isTerminal) {
        await _stopStreams();
        return;
      }
      // Once offers have arrived there's nothing left to watch for — the screen
      // now shows the review CTA and the user moves on.
      if (request.hasOffers) {
        await _refreshSubscription?.cancel();
        _refreshSubscription = null;
      }
    } on WaitingException catch (e) {
      // A contract violation is NOT transient: retrying re-reads the same
      // broken payload. Fail loudly and stop, rather than quietly polling a
      // gateway that cannot answer the offer-wait contract.
      if (e.failure == WaitingFailure.contractViolation) {
        await _failContract(e);
        return;
      }
      // Network blip / 5xx — stay quiet; the foreground load/retry path
      // surfaces errors; we don't flash a banner every poll on a flaky network.
    } catch (_) {
      /* same — swallow */
    } finally {
      _pollInFlight = false;
    }
  }

  /// Terminal backend-contract failure. Emitted from BOTH the cold load and the
  /// push path so the two behave identically: diag breadcrumb, tear the refresh
  /// AND clock streams down, then surface the distinct contract-break state.
  Future<void> _failContract(WaitingException e) async {
    Diag.event('waiting_contract_violation', <String, Object?>{
      'requestId': _requestId,
      'detail': e.message,
    });
    await _stopStreams();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: WaitingScreenStatus.failed,
        error: WaitingFailure.contractViolation,
      ),
    );
  }

  Future<void> _stopStreams() async {
    await _refreshSubscription?.cancel();
    await _clockSubscription?.cancel();
    _refreshSubscription = null;
    _clockSubscription = null;
  }

  @override
  Future<void> close() async {
    await _stopStreams();
    return super.close();
  }
}
