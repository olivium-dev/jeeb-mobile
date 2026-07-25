import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';
import 'waiting_state.dart';

/// Drives the JM-026 waiting / no-coverage screen.
///
/// Responsibilities (mirrors `ClientOffersCubit`, T-mobile-015 pattern):
///  - Cold-load the pre-accept request snapshot (notified count, anchor pair)
///  - Poll so freshly-arrived offers flip the screen to the review CTA live
///    (AC2) without a manual refresh
///  - Drive the countdown via an injected clock against the snapshot's
///    server-anchored deadline — the cubit NEVER invents a window (P7)
///
/// The cubit injects its own clock (`now`) and the poll/clock tick streams so
/// widget tests can fast-forward time deterministically (no real wall-clock
/// timers leak into the test binding).
class WaitingCubit extends Cubit<WaitingState> {
  WaitingCubit({
    required WaitingRepository repository,
    required String requestId,
    DateTime Function()? now,
    Duration pollInterval = const Duration(seconds: 5),
    Duration tickInterval = const Duration(seconds: 1),
    Stream<void>? pollTicks,
    Stream<void>? clockTicks,
  }) : _repository = repository,
       _requestId = requestId,
       _now = now ?? DateTime.now,
       _pollInterval = pollInterval,
       _tickInterval = tickInterval,
       _externalPollTicks = pollTicks,
       _externalClockTicks = clockTicks,
       super(const WaitingState());

  final WaitingRepository _repository;
  final String _requestId;
  final DateTime Function() _now;
  final Duration _pollInterval;
  final Duration _tickInterval;
  final Stream<void>? _externalPollTicks;
  final Stream<void>? _externalClockTicks;

  StreamSubscription<void>? _pollSubscription;
  StreamSubscription<void>? _clockSubscription;

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
      // Offers are in — stop polling for them.
      await _pollSubscription?.cancel();
      _pollSubscription = null;
    } catch (_) {
      /* swallow — broadcast state stays up */
    }
  }

  /// Manual retry from the error state. Resets to initial so [load] re-runs.
  Future<void> retry() async {
    if (isClosed) return;
    await _pollSubscription?.cancel();
    await _clockSubscription?.cancel();
    _pollSubscription = null;
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
    _pollSubscription =
        (_externalPollTicks ?? Stream.periodic(_pollInterval, (_) {})).listen(
          (_) => _poll(),
        );
    _clockSubscription =
        (_externalClockTicks ?? Stream.periodic(_tickInterval, (_) {})).listen(
          (_) => tick(),
        );
  }

  Future<void> _poll() async {
    if (state.isTerminal || _pollInFlight) return;
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
      // Once offers have arrived there's nothing left to poll for — the screen
      // now shows the review CTA and the user moves on.
      if (request.hasOffers) {
        await _pollSubscription?.cancel();
        _pollSubscription = null;
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
  /// poll so the two paths behave identically: diag breadcrumb, tear the poll
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
    await _pollSubscription?.cancel();
    await _clockSubscription?.cancel();
    _pollSubscription = null;
    _clockSubscription = null;
  }

  @override
  Future<void> close() async {
    await _stopStreams();
    return super.close();
  }
}
