import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../../../core/network/app_failure.dart';
import '../../cancel_request/application/cancelled_request_signals.dart';
import '../domain/client_home_repository.dart';
import '../domain/client_home_request.dart';
import 'client_home_state.dart';

const Duration kClientHomeRateLimitFallbackWindow = Duration(seconds: 10);

class ClientHomeCubit extends Cubit<ClientHomeState>
    implements PollingVisibility {
  ClientHomeCubit({
    required ClientHomeRepository repository,
    required String? Function() greetingNameProvider,
    Stream<void>? refreshSignals,
    Stream<String>? cancelledRequestSignals,
  }) : _repository = repository,
       _greetingNameProvider = greetingNameProvider,
       super(const ClientHomeState()) {
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ClientHomeCubit',
    );
    // F9: NOT routed through the visibility gate — a landed cancel is local
    // truth, not a read, so it applies while the list is off screen.
    _cancelledSubscription =
        (cancelledRequestSignals ?? resolveCancelledRequestSignals().stream)
            .listen(removeRequest);
  }

  final ClientHomeRepository _repository;
  final String? Function() _greetingNameProvider;
  late final DeferredRefreshGate _refreshGate;
  late final StreamSubscription<String> _cancelledSubscription;

  @visibleForTesting
  int get debugFetchCount => _fetchCount;
  int _fetchCount = 0;

  DateTime? _rateLimitedUntil;
  Timer? _rateLimitRetryTimer;

  /// Ids already cancelled locally. Held until the server stops sending them,
  /// so an in-flight read started before the cancel cannot resurrect the row.
  final Set<String> _cancelledIds = <String>{};

  List<ClientHomeRequest> _withoutCancelled(List<ClientHomeRequest> rows) {
    if (_cancelledIds.isEmpty) return rows;
    return rows.where((r) => !_cancelledIds.contains(r.id)).toList();
  }

  void _pruneConvergedCancellations(ClientHomeSnapshot snapshot) {
    if (_cancelledIds.isEmpty ||
        snapshot.rateLimited ||
        snapshot.requestsFailure != null) {
      return;
    }
    final present = <String>{
      for (final r in snapshot.pending) r.id,
      for (final r in snapshot.replies) r.id,
      for (final r in snapshot.offerStatusRequests) r.id,
    };
    _cancelledIds.removeWhere((id) => !present.contains(id));
  }

  Future<void> load() async {
    if (state.status == ClientHomeStatus.loading) return;
    emit(
      state.copyWith(
        status: ClientHomeStatus.loading,
        greetingName: _greetingNameProvider(),
      ),
    );
    await _fetch();
    await _drainQueuedRefresh();
  }

  bool _refreshInFlight = false;
  bool _refreshQueued = false;

  /// F9: a refresh request is never dropped. Every early return here used to
  /// destroy the only re-read a landed cancel or push had.
  Future<void> refresh() async {
    if (state.status == ClientHomeStatus.loading || _refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    final backoffUntil = _rateLimitedUntil;
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil)) {
      _scheduleRateLimitedRefresh(backoffUntil);
      return;
    }
    _refreshInFlight = true;
    try {
      await _fetch();
    } finally {
      _refreshInFlight = false;
    }
    await _drainQueuedRefresh();
  }

  /// Collapses any number of requests deferred during one round trip into a
  /// single follow-up read.
  Future<void> _drainQueuedRefresh() async {
    if (!_refreshQueued || isClosed) return;
    _refreshQueued = false;
    await refresh();
  }

  void _scheduleRateLimitedRefresh(DateTime until) {
    if (_rateLimitRetryTimer?.isActive ?? false) return;
    final delay = until.difference(DateTime.now());
    _rateLimitRetryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _rateLimitRetryTimer = null;
        if (isClosed) return;
        unawaited(refresh());
      },
    );
  }

  /// Optimistic truth: the row goes the moment its DELETE lands, without
  /// waiting for a re-read that the visibility gate may still be holding.
  void removeRequest(String requestId) {
    if (isClosed || requestId.isEmpty) return;
    bool keep(ClientHomeRequest request) => request.id != requestId;
    final pending = state.pending.where(keep).toList();
    final replies = state.replies.where(keep).toList();
    final offerStatus = state.offerStatusRequests.where(keep).toList();
    final removedAny = pending.length != state.pending.length ||
        replies.length != state.replies.length ||
        offerStatus.length != state.offerStatusRequests.length;
    _cancelledIds.add(requestId);
    if (!removedAny) return;
    emit(
      state.copyWith(
        pending: pending,
        replies: replies,
        offerStatusRequests: offerStatus,
      ),
    );
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

      final pendingRows = _withoutCancelled(snapshot.pending);
      final repliesRows = _withoutCancelled(snapshot.replies);
      final offerStatusRows = _withoutCancelled(snapshot.offerStatusRequests);
      _pruneConvergedCancellations(snapshot);

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
                : pendingRows,
            replies: snapshot.requestsFailure != null
                ? state.replies
                : repliesRows,
            recentDeliveries: snapshot.recentFailure != null
                ? state.recentDeliveries
                : snapshot.recentDeliveries.take(1).toList(),
            offerStatusRequests: snapshot.requestsFailure != null
                ? state.offerStatusRequests
                : offerStatusRows,
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
          pending: pendingRows,
          replies: repliesRows,
          recentDeliveries: snapshot.recentDeliveries.take(1).toList(),
          offerStatusRequests: offerStatusRows,
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
    _refreshQueued = false;
    _rateLimitRetryTimer?.cancel();
    _rateLimitRetryTimer = null;
    unawaited(_cancelledSubscription.cancel());
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}
