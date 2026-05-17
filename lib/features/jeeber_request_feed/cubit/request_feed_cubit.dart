import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
import 'request_feed_state.dart';

/// Optional side-effect hook the host wires up to play a notification sound
/// every time a new request enters the feed. Kept as a function (not a
/// service interface) because the only call site is `audioplayers.play()`
/// — defining a one-method interface would be ceremony for no benefit.
///
/// The cubit invokes [SoundNotifier] exactly once per new request id; it's
/// not called for cancellations, snapshot rehydration, or actions.
typedef SoundNotifier = void Function();

/// Drives the Jeeber request feed (JEEB-66 / T-mobile-013).
///
/// Three live subscriptions:
///   1. [RequestFeedRepository.requests] — new requests fan into the feed
///      (deduped by id) and trigger [SoundNotifier].
///   2. [RequestFeedRepository.cancellations] — gateway-side dismissals pop
///      cards off the feed mid-flight.
///   3. [RequestFeedRepository.transport] — flips the WebSocket vs polling
///      badge in the screen layer.
///
/// Plus a single periodic timer that retires cards whose `expiresAt` has
/// passed, or whose client-side timeout (the [requestTimeout] window from
/// the moment the card was added) has elapsed — whichever fires first.
class RequestFeedCubit extends Cubit<RequestFeedState> {
  RequestFeedCubit({
    required RequestFeedRepository repository,
    Duration requestTimeout = const Duration(seconds: 60),
    Duration sweepInterval = const Duration(seconds: 1),
    SoundNotifier? onNewRequestSound,
    DateTime Function()? clock,
  })  : _repository = repository,
        _requestTimeout = requestTimeout,
        _sweepInterval = sweepInterval,
        _onNewRequestSound = onNewRequestSound,
        _clock = clock ?? DateTime.now,
        super(const RequestFeedState());

  final RequestFeedRepository _repository;
  final Duration _requestTimeout;
  final Duration _sweepInterval;
  final SoundNotifier? _onNewRequestSound;
  final DateTime Function() _clock;

  StreamSubscription<DeliveryRequest>? _requestsSub;
  StreamSubscription<String>? _cancellationsSub;
  StreamSubscription<FeedTransportUpdate>? _transportSub;
  Timer? _sweep;

  /// Per-request deadline (the earlier of `expiresAt` and the client-side
  /// [requestTimeout] from add time). Used by [_sweepExpired] to retire
  /// cards. Kept off [RequestFeedState] so each tick doesn't churn the
  /// equality check across the entire feed.
  final Map<String, DateTime> _deadlines = {};

  /// Boot the live subscriptions and pull an initial snapshot.
  Future<void> start() async {
    _requestsSub ??= _repository.requests.listen(_onIncoming);
    _cancellationsSub ??= _repository.cancellations.listen(_onCancellation);
    _transportSub ??= _repository.transport.listen(_onTransport);
    _sweep ??= Timer.periodic(_sweepInterval, (_) => _sweepExpired());
    await refresh();
  }

  /// Manual refresh — pulls the latest snapshot from the gateway and merges
  /// it with the in-memory feed. Surfaces a one-shot loading state on the
  /// initial fetch so the screen can render a spinner, but stays silent on
  /// subsequent pulls (the OMDS pull-to-refresh chrome owns the affordance).
  Future<void> refresh() async {
    final isInitial = state.status == RequestFeedStatus.initial;
    if (isInitial) {
      emit(state.copyWith(
        status: RequestFeedStatus.loading,
        errorMessageKey: null,
      ));
    }
    try {
      final snapshot = await _repository.refresh();
      final byId = {for (final r in state.requests) r.id: r};
      for (final r in snapshot) {
        if (!byId.containsKey(r.id)) _trackDeadline(r);
        byId[r.id] = r;
      }
      emit(state.copyWith(
        status: RequestFeedStatus.ready,
        requests: _sorted(byId.values),
        errorMessageKey: null,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: state.requests.isEmpty
            ? RequestFeedStatus.error
            : RequestFeedStatus.ready,
        errorMessageKey: 'requestFeedErrorLoad',
      ));
    }
  }

  /// User tapped the accept button on a card. The card stays on screen with
  /// a pending indicator until the gateway responds; on success it is
  /// removed (the host routes the Jeeber out of the feed). All non-success
  /// outcomes also remove the card — there's no point keeping a stale
  /// already-taken/expired request on screen — but the cubit emits the
  /// distinct [RequestActionEffect] so the screen layer can flash the right
  /// snackbar.
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
    if (!state.requests.any((r) => r.id == id)) return;
    if (state.actionStatusFor(id) != RequestActionStatus.idle) return;
    emit(state.copyWith(
      actionStatuses: {...state.actionStatuses, id: busy},
    ));
    RequestActionOutcome outcome;
    try {
      outcome = await call(id);
    } catch (_) {
      outcome = RequestActionOutcome.networkError;
    }
    final pendingRemoved = Map<String, RequestActionStatus>.from(
      state.actionStatuses,
    )..remove(id);
    if (outcome == RequestActionOutcome.networkError) {
      // Surface the error but keep the card so the Jeeber can retry.
      emit(state.copyWith(
        actionStatuses: pendingRemoved,
        lastEffect: RequestActionEffect(requestId: id, outcome: outcome),
      ));
      return;
    }
    _deadlines.remove(id);
    emit(state.copyWith(
      requests: state.requests.where((r) => r.id != id).toList(growable: false),
      actionStatuses: pendingRemoved,
      lastEffect: RequestActionEffect(requestId: id, outcome: outcome),
    ));
  }

  /// Acknowledged by the screen layer after rendering a snackbar — clears
  /// the transient effect so [BlocConsumer.listenWhen] doesn't replay it.
  void clearEffect() {
    if (state.lastEffect == null) return;
    emit(state.copyWith(lastEffect: null));
  }

  void _onIncoming(DeliveryRequest request) {
    final exists = state.requests.any((r) => r.id == request.id);
    final byId = {for (final r in state.requests) r.id: r};
    byId[request.id] = request;
    _trackDeadline(request);
    if (!exists) _onNewRequestSound?.call();
    emit(state.copyWith(
      status: RequestFeedStatus.ready,
      requests: _sorted(byId.values),
    ));
  }

  void _onCancellation(String requestId) {
    if (!state.requests.any((r) => r.id == requestId)) return;
    _deadlines.remove(requestId);
    final pendingRemoved = Map<String, RequestActionStatus>.from(
      state.actionStatuses,
    )..remove(requestId);
    emit(state.copyWith(
      requests:
          state.requests.where((r) => r.id != requestId).toList(growable: false),
      actionStatuses: pendingRemoved,
    ));
  }

  void _onTransport(FeedTransportUpdate update) {
    if (state.transport == update.transport) return;
    emit(state.copyWith(transport: update.transport));
  }

  void _sweepExpired() {
    final now = _clock();
    final expired = _deadlines.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    if (expired.isEmpty) return;
    for (final id in expired) {
      _deadlines.remove(id);
    }
    final pendingRemoved = Map<String, RequestActionStatus>.from(
      state.actionStatuses,
    )..removeWhere((id, _) => expired.contains(id));
    emit(state.copyWith(
      requests: state.requests
          .where((r) => !expired.contains(r.id))
          .toList(growable: false),
      actionStatuses: pendingRemoved,
    ));
  }

  void _trackDeadline(DeliveryRequest request) {
    final clientDeadline = _clock().add(_requestTimeout);
    final earlier = request.expiresAt.isBefore(clientDeadline)
        ? request.expiresAt
        : clientDeadline;
    _deadlines[request.id] = earlier;
  }

  List<DeliveryRequest> _sorted(Iterable<DeliveryRequest> requests) {
    final list = requests.toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return List.unmodifiable(list);
  }

  @override
  Future<void> close() async {
    _sweep?.cancel();
    _sweep = null;
    await _requestsSub?.cancel();
    await _cancellationsSub?.cancel();
    await _transportSub?.cancel();
    await _repository.dispose();
    return super.close();
  }
}
