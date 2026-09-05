import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';
import 'waiting_state.dart';

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

  final Stream<void>? _refreshSignals;

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _clockSubscription;

  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  bool _pollInFlight = false;

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
      unawaited(_enrichWithOffers());
    } on WaitingException catch (e) {
      if (isClosed) return;
      if (e.failure == WaitingFailure.contractViolation) {
        await _failContract(e);
        return;
      }
      emit(
        state.copyWith(
          status: WaitingScreenStatus.failed,
          error: e.failure,
          appFailure: e.appFailure,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: WaitingScreenStatus.failed,
          error: WaitingFailure.unknown,
          appFailure: AppFailure.of(e),
        ),
      );
    }
  }

  /// Clears the warm refresh band after the user dismisses it.
  void acknowledgeRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  /// A single blip is noise; two in a row is a state worth telling the user
  /// about.
  static const int _refreshFailureThreshold = 2;
  int _consecutiveRefreshFailures = 0;

  void _recordRefreshFailure(String event, Object error) {
    final AppFailure failure = error is WaitingException
        ? error.appFailure
        : AppFailure.of(error);
    Diag.event(event, <String, Object?>{'kind': failure.kind.name});
    _consecutiveRefreshFailures++;
    if (isClosed || _consecutiveRefreshFailures < _refreshFailureThreshold) {
      return;
    }
    emit(state.copyWith(refreshError: failure));
  }

  Future<void> _enrichWithOffers() async {
    final request = state.request;
    if (request == null || request.phase.isTerminal) return;
    try {
      final offerCount = await _repository.fetchOfferCount(_requestId);
      if (isClosed) return;
      if (offerCount == null) {
        // UX-34: unknown, never a fabricated count.
        emit(state.copyWith(offerCountUnavailable: true));
        return;
      }
      _consecutiveRefreshFailures = 0;
      final latest = state.request;
      if (latest == null || latest.phase.isTerminal) return;
      emit(state.copyWith(offerCountUnavailable: false));
      if (offerCount <= latest.offerCount) return;
      emit(
        state.copyWith(
          request: latest.copyWith(
            phase: WaitingRequestPhase.offersArrived,
            offerCount: offerCount,
          ),
          now: _now(),
        ),
      );
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
    } catch (e) {
      if (isClosed) return;
      _recordRefreshFailure('waiting_offer_enrich_failed', e);
    }
  }

  void refreshOnResume() {
    if (isClosed || state.status != WaitingScreenStatus.loaded) return;
    unawaited(_refreshFromPush());
  }

  /// Warm retry from the refresh band: re-reads in place, keeping the request
  /// on screen. R6 — refresh never flips the screen back to loading.
  Future<void> refresh() async {
    if (isClosed || state.status != WaitingScreenStatus.loaded) return;
    await _refreshFromPush();
  }

  /// Cold retry from the failed rung: rebuilds the screen from scratch.
  Future<void> retry() async {
    if (isClosed) return;
    await _refreshSubscription?.cancel();
    await _clockSubscription?.cancel();
    _refreshSubscription = null;
    _clockSubscription = null;
    emit(const WaitingState());
    await load();
  }

  void tick() {
    if (isClosed || state.isTerminal) return;
    emit(state.copyWith(now: _now()));
  }

  void _attachStreams() {
    _refreshSubscription = _refreshSignals?.listen((_) => _refreshFromPush());
    _clockSubscription =
        (_externalClockTicks ?? Stream.periodic(_tickInterval, (_) {})).listen(
          (_) => tick(),
        );
  }

  Future<void> _refreshFromPush() async {
    if (isClosed || state.isTerminal || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final request = await _repository.fetchWaiting(_requestId);
      if (isClosed) return;
      _consecutiveRefreshFailures = 0;
      final observedAt = _now();
      emit(
        state.copyWith(
          request: request,
          now: observedAt,
          offerCountUnavailable: !request.offerCountIsProbed,
          clearRefreshError: true,
        ),
      );
      if (request.phase.isTerminal) {
        await _stopStreams();
        return;
      }
      if (request.hasOffers) {
        await _refreshSubscription?.cancel();
        _refreshSubscription = null;
      }
    } on WaitingException catch (e) {
      if (e.failure == WaitingFailure.contractViolation) {
        await _failContract(e);
        return;
      }
      _recordRefreshFailure('waiting_push_refresh_failed', e);
    } catch (e) {
      _recordRefreshFailure('waiting_push_refresh_failed', e);
    } finally {
      _pollInFlight = false;
    }
  }

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
        appFailure: UnknownFailure(cause: e, parse: true),
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
