import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../../../core/network/app_failure.dart';
import '../domain/client_home_repository.dart';
import 'client_home_state.dart';

const Duration kClientHomeRateLimitFallbackWindow = Duration(seconds: 10);

class ClientHomeCubit extends Cubit<ClientHomeState>
    implements PollingVisibility {
  ClientHomeCubit({
    required ClientHomeRepository repository,
    required String? Function() greetingNameProvider,
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       _greetingNameProvider = greetingNameProvider,
       super(const ClientHomeState()) {
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ClientHomeCubit',
    );
  }

  final ClientHomeRepository _repository;
  final String? Function() _greetingNameProvider;
  late final DeferredRefreshGate _refreshGate;

  @visibleForTesting
  int get debugFetchCount => _fetchCount;
  int _fetchCount = 0;

  DateTime? _rateLimitedUntil;

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

  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (state.status == ClientHomeStatus.loading) return;
    if (_refreshInFlight) return;
    final backoffUntil = _rateLimitedUntil;
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil)) return;
    _refreshInFlight = true;
    try {
      await _fetch();
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  void setPollingVisible(bool visible) =>
      _refreshGate.setPollingVisible(visible);

  /// Clears the warm refresh band after the user dismisses it.
  void acknowledgeRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _fetch() async {
    _fetchCount++;
    try {
      final snapshot = await _repository.loadSnapshot();
      if (isClosed) return;

      if (snapshot.rateLimited) {
        _rateLimitedUntil = DateTime.now().add(
          snapshot.retryAfter ?? kClientHomeRateLimitFallbackWindow,
        );
        if (state.status == ClientHomeStatus.ready) return;
      } else {
        _rateLimitedUntil = null;
      }

      // B1: the repo degrades transport failures into empty lists, so an
      // all-failed load must be read as failed, not as a healthy empty home.
      if (snapshot.allPrimaryFailed) {
        if (state.status != ClientHomeStatus.ready) {
          emit(
            state.copyWith(
              status: ClientHomeStatus.failed,
              error: snapshot.firstFailure ?? const UnknownFailure(),
            ),
          );
        } else {
          emit(
            state.copyWith(
              refreshError: snapshot.firstFailure ?? const UnknownFailure(),
            ),
          );
        }
        return;
      }

      // R6: a warm refresh that loses a read keeps the rows it already has and
      // reports the loss in the refresh band — it never blanks a live tab.
      final bool warmPartial =
          state.status == ClientHomeStatus.ready && snapshot.anyBucketFailed;
      if (warmPartial) {
        emit(
          state.copyWith(
            status: ClientHomeStatus.ready,
            inProgress: snapshot.inProgressFailure != null
                ? state.inProgress
                : snapshot.inProgress,
            pending: snapshot.requestsFailure != null
                ? state.pending
                : snapshot.pending,
            replies: snapshot.requestsFailure != null
                ? state.replies
                : snapshot.replies,
            recentDeliveries: snapshot.recentFailure != null
                ? state.recentDeliveries
                : snapshot.recentDeliveries.take(1).toList(),
            offerStatusRequests: snapshot.requestsFailure != null
                ? state.offerStatusRequests
                : snapshot.offerStatusRequests,
            clearError: true,
            clearBucketErrors: true,
            refreshError: snapshot.firstFailure,
          ),
        );
        return;
      }

      // ES-10/F7: a cold partial failure keeps every bucket that loaded and
      // marks only the dead ones.
      emit(
        state.copyWith(
          status: ClientHomeStatus.ready,
          inProgress: snapshot.inProgress,
          pending: snapshot.pending,
          replies: snapshot.replies,
          recentDeliveries: snapshot.recentDeliveries.take(1).toList(),
          offerStatusRequests: snapshot.offerStatusRequests,
          clearError: true,
          clearRefreshError: true,
          clearBucketErrors: true,
          inProgressError: snapshot.inProgressFailure,
          pendingError: snapshot.requestsFailure,
          repliesError: snapshot.requestsFailure,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final AppFailure failure = AppFailure.of(e);
      if (state.status == ClientHomeStatus.ready) {
        emit(state.copyWith(refreshError: failure));
        return;
      }
      emit(
        state.copyWith(status: ClientHomeStatus.failed, error: failure),
      );
    }
  }

  @override
  Future<void> close() {
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}
