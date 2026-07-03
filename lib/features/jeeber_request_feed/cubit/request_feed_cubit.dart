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
/// not called for snapshot rehydration or actions.
typedef SoundNotifier = void Function();

/// Drives the Jeeber request feed (JEEB-66 / T-mobile-013).
///
/// Two live subscriptions:
///   1. [RequestFeedRepository.requests] — new requests fan into the feed
///      (deduped by id) and trigger [SoundNotifier].
///   2. [RequestFeedRepository.transport] — flips the WebSocket vs polling
///      badge in the screen layer.
///
/// Requests LEAVE the feed via (a) the snapshot-authoritative [refresh]
/// reconcile — a request the gateway no longer lists is dropped; (b) the
/// periodic timer that first flips a card whose server `expiresAt` has passed
/// into a visible EXPIRED state, then removes it once [expiredLinger] elapses;
/// or (c) a completed accept/decline.
/// (There is no separate cancellations stream — no backend ever produced one.)
///
/// G3 (sprint-009): the server `expiresAt` is the ONLY lifetime authority.
/// The old client-side `requestTimeout` — `min(expiresAt, addTime + 60s)` —
/// silently retired cards FOUR MINUTES before the server's 5:00 broadcast
/// window, so a jeeber who dismissed the push and opened the app 90s later
/// saw "No requests" for a request that was still live. A payload missing
/// `expiresAt` is defaulted at PARSE time (`dio_request_feed_repository`
/// stamps now+5min), so no client-side truncation is ever needed here.
class RequestFeedCubit extends Cubit<RequestFeedState> {
  RequestFeedCubit({
    required RequestFeedRepository repository,
    Duration expiredLinger = const Duration(seconds: 30),
    Duration sweepInterval = const Duration(seconds: 1),
    SoundNotifier? onNewRequestSound,
    DateTime Function()? clock,
  })  : _repository = repository,
        _expiredLinger = expiredLinger,
        _sweepInterval = sweepInterval,
        _onNewRequestSound = onNewRequestSound,
        _clock = clock ?? DateTime.now,
        super(const RequestFeedState());

  final RequestFeedRepository _repository;

  /// How long an expired card stays on screen (visibly marked "Expired",
  /// actions disabled) before the sweep collapses it out of the list — the
  /// graceful exit G3 requires instead of a silent vanish.
  final Duration _expiredLinger;
  final Duration _sweepInterval;
  final SoundNotifier? _onNewRequestSound;
  final DateTime Function() _clock;

  StreamSubscription<DeliveryRequest>? _requestsSub;
  StreamSubscription<FeedTransportUpdate>? _transportSub;
  Timer? _sweep;

  /// Per-request expiry deadline — the request's own server `expiresAt`,
  /// verbatim. Used by [_sweepExpired] to flip cards into the expired state.
  /// Kept off [RequestFeedState] so each tick doesn't churn the equality
  /// check across the entire feed.
  final Map<String, DateTime> _deadlines = {};

  /// Per-request removal deadline for cards already expired: `expiredAt +
  /// [_expiredLinger]`. When it passes, [_sweepExpired] removes the card.
  final Map<String, DateTime> _removals = {};

  /// Boot the live subscriptions and pull an initial snapshot.
  Future<void> start() async {
    _requestsSub ??= _repository.requests.listen(_onIncoming);
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
      // Snapshot-authoritative reconcile: the gateway snapshot is the source of
      // truth. A request the gateway has since dropped (cancelled by the sender,
      // taken by another jeeber, or expired) is NOT in the snapshot and must
      // leave the feed — the old additive merge kept such stale cards forever.
      // Existing rows we preserve: (a) rows with an action in flight, so a
      // refresh landing mid-accept/decline doesn't yank the card out from
      // under the user before its effect resolves; and (b) rows in their
      // expired-linger window, so the graceful "Expired" exit isn't cut short
      // by a refresh — the sweep owns their removal.
      final existingById = {for (final r in state.requests) r.id: r};
      final reconciled = <String, DeliveryRequest>{};
      final expiredIds = <String>{...state.expiredIds};
      for (final r in snapshot) {
        // A row the server STILL lists is live by definition — if we had
        // locally expired it (clock skew), revive it off the fresh row.
        final wasExpired = expiredIds.remove(r.id);
        if (!existingById.containsKey(r.id) || wasExpired) _trackDeadline(r);
        reconciled[r.id] = r;
      }
      for (final entry in existingById.entries) {
        if (reconciled.containsKey(entry.key)) continue;
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
    // An expired card is display-only during its linger window — the request
    // is dead server-side, so accept/decline would only round-trip an error.
    if (state.isExpired(id)) return;
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
    _removals.remove(id);
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
    // A re-pushed id is live again by definition — drop any expired mark.
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

  /// Two-phase retirement so cards never silently vanish (G3):
  ///
  ///  1. A card whose server `expiresAt` has passed is MARKED expired — it
  ///     stays on screen, visibly flipped to its "Expired" look with actions
  ///     disabled — and its removal is scheduled at `now + expiredLinger`.
  ///  2. A card whose linger window has elapsed is removed from the feed.
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

  /// The server `expiresAt` is the one and only deadline — no client-side
  /// truncation (G3). Re-tracking an id also clears any scheduled removal,
  /// so a re-listed/re-pushed request is live again.
  void _trackDeadline(DeliveryRequest request) {
    _deadlines[request.id] = request.expiresAt;
    _removals.remove(request.id);
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
    await _transportSub?.cancel();
    await _repository.dispose();
    return super.close();
  }
}
