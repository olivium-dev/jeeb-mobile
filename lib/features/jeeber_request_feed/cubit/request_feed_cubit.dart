import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/lifecycle_poller.dart';
import '../../../core/lifecycle/polling_source.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../../../core/network/app_failure.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
import 'request_feed_state.dart';

typedef SoundNotifier = void Function();

enum RequestFeedRepositoryOwnership {

  owned,

  borrowed,
}

class RequestFeedCubit extends Cubit<RequestFeedState>
    implements PollingVisibility {
  RequestFeedCubit({
    required RequestFeedRepository repository,
    RequestFeedRepositoryOwnership repositoryOwnership =
        RequestFeedRepositoryOwnership.owned,
    Duration expiredLinger = const Duration(seconds: 30),
    Duration sweepInterval = const Duration(seconds: 1),
    SoundNotifier? onNewRequestSound,
    DateTime Function()? clock,
    Stream<void>? refreshSignals,
  })  : _repository = repository,
        _refreshSignals = refreshSignals,
        _source =
            repository is PollingSource ? repository as PollingSource : null,
        _repositoryOwnership = repositoryOwnership,
        _expiredLinger = expiredLinger,
        _sweepInterval = sweepInterval,
        _onNewRequestSound = onNewRequestSound,
        _clock = clock ?? DateTime.now,
        super(const RequestFeedState());

  final RequestFeedRepository _repository;
  final PollingSource? _source;
  final RequestFeedRepositoryOwnership _repositoryOwnership;
  bool _pollingVisible = false;

  final Duration _expiredLinger;
  final Duration _sweepInterval;
  final SoundNotifier? _onNewRequestSound;
  final DateTime Function() _clock;

  final Stream<void>? _refreshSignals;

  StreamSubscription<DeliveryRequest>? _requestsSub;
  StreamSubscription<FeedTransportUpdate>? _transportSub;
  late final DeferredRefreshGate _refreshGate = DeferredRefreshGate(
    onRefresh: refresh,
    debugLabel: 'RequestFeedCubit',
  );
  late final LifecyclePoller _sweepPoller = LifecyclePoller(
    interval: _sweepInterval,
    onTick: _sweepExpired,
    tickOnResume: true,
    debugLabel: 'RequestFeedCubit expiry sweep',
  );

  final Map<String, DateTime> _deadlines = {};

  final Map<String, DateTime> _removals = {};

  Future<void> start() async {
    _requestsSub ??= _repository.requests.listen(_onIncoming);
    _transportSub ??= _repository.transport.listen(_onTransport);

    _refreshGate.bind(_refreshSignals);
    _sweepPoller.start();
    _applyPollInterest();
    await refresh();
  }

  @override
  void setPollingVisible(bool visible) {

    _sweepPoller.setPollingVisible(visible);

    _refreshGate.setPollingVisible(visible);
    if (_pollingVisible == visible) return;
    _pollingVisible = visible;
    _applyPollInterest();
  }

  void _applyPollInterest() {
    final source = _source;
    if (source == null || _transportSub == null) return;
    if (_pollingVisible) {
      source.addPollInterest(this);
    } else {
      source.removePollInterest(this);
    }
  }

  Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      await _refresh();
    } finally {
      _refreshInFlight = false;
    }
  }

  bool _refreshInFlight = false;

  Future<void> _refresh() async {
    final isInitial = state.status == RequestFeedStatus.initial;
    if (isInitial) {
      emit(state.copyWith(
        status: RequestFeedStatus.loading,
        error: null,
      ));
    }
    try {
      final snapshot = await _repository.refresh();

      final existingById = {for (final r in state.requests) r.id: r};
      final reconciled = <String, DeliveryRequest>{};
      final expiredIds = <String>{...state.expiredIds};
      final serverClosedIds = <String>{};
      for (final r in snapshot) {

        if (!r.requestIsOpen) {
          serverClosedIds.add(r.id);
          expiredIds.remove(r.id);
          _deadlines.remove(r.id);
          _removals.remove(r.id);
          continue;
        }

        expiredIds.remove(r.id);

        _trackDeadline(r);
        reconciled[r.id] = r;
      }
      for (final entry in existingById.entries) {
        if (reconciled.containsKey(entry.key)) continue;
        if (serverClosedIds.contains(entry.key)) continue;
        final inFlight =
            state.actionStatusFor(entry.key) != RequestActionStatus.idle;
        if (inFlight || expiredIds.contains(entry.key)) {
          reconciled[entry.key] = entry.value;
        } else {
          _deadlines.remove(entry.key);
          _removals.remove(entry.key);
        }
      }
      emit(state.copyWith(
        status: RequestFeedStatus.ready,
        requests: _sorted(reconciled.values),
        expiredIds: expiredIds,
        error: null,
        refreshError: null,
      ));
    } catch (e) {
      final failure = AppFailure.of(e);
      // A warm failure keeps the rows; only a cold one owns the screen.
      emit(state.requests.isEmpty
          ? state.copyWith(
              status: RequestFeedStatus.error,
              error: failure,
              refreshError: null,
            )
          : state.copyWith(
              status: RequestFeedStatus.ready,
              refreshError: failure,
            ));
    }
  }

  Future<void> accept(String id) =>
      _act(id: id, busy: RequestActionStatus.accepting, call: _repository.accept);

  Future<void> decline(String id) => _act(
        id: id,
        busy: RequestActionStatus.declining,
        call: _repository.decline,
      );

  Future<void> _act({
    required String id,
    required RequestActionStatus busy,
    required Future<RequestActionOutcome> Function(String) call,
  }) async {
    final requestIndex = state.requests.indexWhere((r) => r.id == id);
    if (requestIndex == -1 || !state.requests[requestIndex].requestIsOpen) {
      return;
    }

    if (state.isExpired(id)) return;
    if (state.actionStatusFor(id) != RequestActionStatus.idle) return;
    emit(state.copyWith(
      actionStatuses: {...state.actionStatuses, id: busy},
    ));
    RequestActionOutcome outcome;
    AppFailure? failure;
    try {
      outcome = await call(id);
    } catch (e) {
      failure = AppFailure.of(e);
      outcome = RequestActionOutcome.networkError;
    }
    final pendingRemoved = Map<String, RequestActionStatus>.from(
      state.actionStatuses,
    )..remove(id);
    if (outcome == RequestActionOutcome.networkError) {

      emit(state.copyWith(
        actionStatuses: pendingRemoved,
        lastEffect: RequestActionEffect(
          requestId: id,
          action: busy,
          outcome: outcome,
          failure: failure,
        ),
      ));
      return;
    }
    _deadlines.remove(id);
    _removals.remove(id);
    emit(state.copyWith(
      requests: state.requests.where((r) => r.id != id).toList(growable: false),
      actionStatuses: pendingRemoved,
      lastEffect: RequestActionEffect(
        requestId: id,
        action: busy,
        outcome: outcome,
        failure: failure,
      ),
    ));
  }

  void clearEffect() {
    if (state.lastEffect == null) return;
    emit(state.copyWith(lastEffect: null));
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(refreshError: null));
  }

  void _onIncoming(DeliveryRequest request) {
    if (!request.requestIsOpen) {
      _deadlines.remove(request.id);
      _removals.remove(request.id);
      final requests = state.requests
          .where((r) => r.id != request.id)
          .toList(growable: false);
      final expiredIds = <String>{...state.expiredIds}..remove(request.id);
      final actionStatuses = Map<String, RequestActionStatus>.from(
        state.actionStatuses,
      )..remove(request.id);
      emit(state.copyWith(
        status: RequestFeedStatus.ready,
        requests: requests,
        expiredIds: expiredIds,
        actionStatuses: actionStatuses,
      ));
      return;
    }
    final exists = state.requests.any((r) => r.id == request.id);
    final byId = {for (final r in state.requests) r.id: r};
    byId[request.id] = request;
    _trackDeadline(request);
    if (!exists) _onNewRequestSound?.call();

    final expiredIds = <String>{...state.expiredIds}..remove(request.id);
    emit(state.copyWith(
      status: RequestFeedStatus.ready,
      requests: _sorted(byId.values),
      expiredIds: expiredIds,
    ));
  }

  void _onTransport(FeedTransportUpdate update) {
    if (state.transport == update.transport) return;
    emit(state.copyWith(transport: update.transport));
  }

  void _sweepExpired() {
    final now = _clock();
    final newlyExpired = _deadlines.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in newlyExpired) {
      _deadlines.remove(id);
      _removals[id] = now.add(_expiredLinger);
    }
    final removed = _removals.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in removed) {
      _removals.remove(id);
    }
    if (newlyExpired.isEmpty && removed.isEmpty) return;
    final expiredIds = <String>{...state.expiredIds, ...newlyExpired}
      ..removeAll(removed);
    final pendingRemoved = Map<String, RequestActionStatus>.from(
      state.actionStatuses,
    )..removeWhere(
        (id, _) => newlyExpired.contains(id) || removed.contains(id),
      );
    emit(state.copyWith(
      requests: state.requests
          .where((r) => !removed.contains(r.id))
          .toList(growable: false),
      expiredIds: expiredIds,
      actionStatuses: pendingRemoved,
    ));
  }

  void _trackDeadline(DeliveryRequest request) {
    final expiresAt = request.expiresAt;
    if (expiresAt == null) {
      _deadlines.remove(request.id);
    } else {
      _deadlines[request.id] = expiresAt;
    }
    _removals.remove(request.id);
  }

  List<DeliveryRequest> _sorted(Iterable<DeliveryRequest> requests) {
    final list = requests.toList()
      ..sort((a, b) {
        final aExpiry = a.expiresAt;
        final bExpiry = b.expiresAt;
        if (aExpiry == null) return bExpiry == null ? 0 : 1;
        if (bExpiry == null) return -1;
        return aExpiry.compareTo(bExpiry);
      });
    return List.unmodifiable(list);
  }

  @override
  Future<void> close() async {
    _source?.removePollInterest(this);
    _sweepPoller.dispose();
    await _requestsSub?.cancel();
    await _transportSub?.cancel();
    await _refreshGate.dispose();
    if (_repositoryOwnership == RequestFeedRepositoryOwnership.owned) {
      await _repository.dispose();
    }
    return super.close();
  }
}
