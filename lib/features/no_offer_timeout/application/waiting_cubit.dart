import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';
import 'waiting_state.dart';

/// Drives the JM-026 waiting / no-coverage screen.
///
/// Responsibilities (mirrors `ClientOffersCubit`, T-mobile-015 pattern):
///  - Cold-load the pre-accept request snapshot (notified count, deadline)
///  - Poll so freshly-arrived offers flip the screen to the review CTA live
///    (AC2) without a manual refresh
///  - Drive the broadcast countdown via an injected clock
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
  })  : _repository = repository,
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

  /// Cold-load entry-point. Two-phase so the broadcast-state signature ids paint
  /// as early as possible (JM-026 AC1):
  ///
  ///  1. Read the request row ONLY (status + notifiedCount + deadline) and emit
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
    emit(state.copyWith(
      status: WaitingScreenStatus.loading,
      now: _now(),
      clearError: true,
    ));
    try {
      final request = await _repository.fetchRequest(_requestId);
      emit(state.copyWith(
        status: WaitingScreenStatus.loaded,
        request: request,
        now: _now(),
        clearError: true,
      ));
      _attachStreams();
      // Phase 2 — layer the offers signal without blocking the first paint.
      unawaited(_enrichWithOffers(request));
    } on WaitingException catch (e) {
      emit(state.copyWith(
        status: WaitingScreenStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WaitingScreenStatus.failed,
        error: WaitingFailure.unknown,
      ));
    }
  }

  /// Best-effort second leg of the cold load: reads the offer count and, if
  /// offers are already in, flips the snapshot to the offers-arrived phase so
  /// `waiting_review_offers_cta` appears (AC2). Never tears down the broadcast
  /// state on failure.
  Future<void> _enrichWithOffers(WaitingRequest request) async {
    try {
      final offerCount = await _repository.fetchOfferCount(
        _requestId,
        fallback: request.offerCount,
      );
      if (isClosed) return;
      if (offerCount <= request.offerCount) return;
      emit(state.copyWith(
        request: WaitingRequest(
          requestId: request.requestId,
          phase: WaitingRequestPhase.offersArrived,
          notifiedCount: request.notifiedCount,
          offerCount: offerCount,
          broadcastExpiresAt: request.broadcastExpiresAt,
          displayId: request.displayId,
          tier: request.tier,
          title: request.title,
        ),
        now: _now(),
      ));
      // Offers are in — stop polling for them.
      await _pollSubscription?.cancel();
      _pollSubscription = null;
    } catch (_) {/* swallow — broadcast state stays up */}
  }

  /// Manual retry from the error state. Resets to initial so [load] re-runs.
  Future<void> retry() async {
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
    emit(state.copyWith(now: _now()));
  }

  void _attachStreams() {
    _pollSubscription =
        (_externalPollTicks ?? Stream.periodic(_pollInterval, (_) {}))
            .listen((_) => _poll());
    _clockSubscription =
        (_externalClockTicks ?? Stream.periodic(_tickInterval, (_) {}))
            .listen((_) => tick());
  }

  Future<void> _poll() async {
    try {
      final request = await _repository.fetchWaiting(_requestId);
      emit(state.copyWith(request: request, now: _now()));
      // Once offers have arrived there's nothing left to poll for — the screen
      // now shows the review CTA and the user moves on.
      if (request.hasOffers) {
        await _pollSubscription?.cancel();
        _pollSubscription = null;
      }
    } on WaitingException catch (_) {
      // Swallow transient poll failures — the foreground load/retry path
      // surfaces errors; we don't flash a banner every poll on a flaky network.
    } catch (_) {/* same — swallow */}
  }

  @override
  Future<void> close() async {
    await _pollSubscription?.cancel();
    await _clockSubscription?.cancel();
    return super.close();
  }
}
