// Designed states for the Jeeber request feed (`RequestFeedScreen`) — ONE

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';

/// Answers every snapshot with an empty board and never pushes.
/// The successful read of an empty feed — NOT a failure. The screen renders
/// these two very differently and the difference is easy to lose.
class EmptyRequestFeedRepository implements RequestFeedRepository {
  const EmptyRequestFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async => const <DeliveryRequest>[];

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}

/// Every snapshot throws, so the cubit lands on [RequestFeedStatus.error] and
/// stays there however many times Retry is pressed.
/// Throws the CLASSIFIED failure from `refresh()`, so a preview can pin the
/// copy family a kind resolves to. [ErrorRequestFeedRepository] stays as-is.
class KindedRequestFeedRepository implements RequestFeedRepository {
  const KindedRequestFeedRepository(this.failure);

  final AppFailure failure;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async => throw failure;

  @override
  Future<RequestActionOutcome> accept(String id) async => throw failure;

  @override
  Future<RequestActionOutcome> decline(String id) async => throw failure;

  @override
  Future<void> dispose() async {}
}

class ErrorRequestFeedRepository implements RequestFeedRepository {
  const ErrorRequestFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async {
    throw Exception('catalog: designed error state');
  }

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<void> dispose() async {}
}

/// The cold read that never comes back, so the screen holds its `loading`
/// branch — the M4 skeleton state, which had no catalog entry before.
class StalledRequestFeedRepository implements RequestFeedRepository {
  const StalledRequestFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() =>
      Completer<List<DeliveryRequest>>().future;

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}

/// Serves a fixed snapshot and reports the DEGRADED transport, which is what
/// puts the reconnecting banner above the list.
class PollingRequestFeedRepository implements RequestFeedRepository {
  const PollingRequestFeedRepository(this._snapshot);

  final List<DeliveryRequest> _snapshot;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.polling);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async =>
      List<DeliveryRequest>.unmodifiable(_snapshot);

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}

/// [RequestFeedCubit] pinned to one designed frame.
/// Never `start()`ed, so none of its three live subscriptions exist and neither
/// the expiry sweep nor the deferred-refresh gate is ever constructed (both are
class SeededRequestFeedScreenCubit extends RequestFeedCubit {
  SeededRequestFeedScreenCubit(
    RequestFeedState seed, {
    RequestFeedRepository? repository,
  }) : super(
          repository: repository ?? SeededRequestFeedRepository(seed.requests),
        ) {
    emit(seed);
  }
}

/// Rows plus a warm failure, emitted without `start()`ing the cubit.
class WarmFailureRequestFeedScreenCubit extends RequestFeedCubit {
  WarmFailureRequestFeedScreenCubit(
    List<DeliveryRequest> rows,
    AppFailure failure,
  ) : super(repository: SeededRequestFeedRepository(rows)) {
    emit(RequestFeedState(
      status: RequestFeedStatus.ready,
      requests: rows,
      refreshError: failure,
    ));
  }
}

/// The designed states of `RequestFeedScreen`, as feeds + inert cubits.
/// Deliberately NOT a widget builder: the catalog needs a live, startable cubit
abstract final class RequestFeedScreenPreviewFixtures {
  /// The Figma screen-24 row, verbatim (`dev-feed-incoming`) — the catalog's
  /// "Incoming — Ignore / Offer card" state.
  static List<DeliveryRequest> incomingFeed() => DevJeeberFeedFixtures.incoming();

  /// The Figma screen-25 row — the jeeber has offered and is awaiting a reply.
  static List<DeliveryRequest> pendingFeed() => DevJeeberFeedFixtures.pending();

  /// The Figma screen-26 rows — accepted, each with its next delivery action.
  static List<DeliveryRequest> acceptedFeed() => DevJeeberFeedFixtures.replies();

  /// One row per [JeeberFeedItemStatus] bucket, each with its own pickup so the
  /// three can be told apart on screen — which is the whole question this feed
  static List<DeliveryRequest> lifecycleFeed() => <DeliveryRequest>[
        _row(
          id: 'preview-feed-incoming',
          pickup: 'Hamra, Beirut',
          dropoff: 'Achrafieh, Beirut',
          distanceKm: 3.4,
          earnings: 5.2,
        ),
        _row(
          id: 'preview-feed-pending',
          pickup: pendingPickupLabel,
          dropoff: 'Badaro, Beirut',
          distanceKm: 6.1,
          earnings: 7.8,
          feedStatus: JeeberFeedItemStatus.pendingResponse,
        ),
        _row(
          id: 'preview-feed-accepted',
          pickup: 'Mar Mikhael, Beirut',
          dropoff: 'Gemmayze, Beirut',
          tier: JeeberRequestTier.light,
          distanceKm: 2.2,
          earnings: 3.1,
          feedStatus: JeeberFeedItemStatus.accepted,
          nextDeliveryAction: JeeberDeliveryAction.orderPicked,
        ),
      ];

  /// The rows already on the board when a later refresh fails.
  static List<DeliveryRequest> staleFeed() => <DeliveryRequest>[
        _row(
          id: 'preview-feed-stale',
          pickup: stalePickupLabel,
          dropoff: 'Sin el Fil, Beirut',
          tier: JeeberRequestTier.bulk,
          distanceKm: 8.4,
          earnings: 11.25,
        ),
      ];

  /// The content ceiling: two addresses long enough to hit the card's
  /// `maxLines: 2` and a six-figure Lebanese-pound amount, which is the home
  static List<DeliveryRequest> longestContentFeed() => <DeliveryRequest>[
        _row(
          id: 'preview-feed-longest',
          pickup: 'Pharmacie Centrale, Rue Sursock, near the Sursock Museum '
              'entrance, Achrafieh, Beirut',
          dropoff: 'Building 12, 4th floor, Rue Abdel Wahab El Inglizi, behind '
              'the Hotel Albergo, Achrafieh, Beirut',
          tier: JeeberRequestTier.flash,
          distanceKm: 18.25,
          earnings: 4500000,
          currency: 'LBP',
        ),
      ];

  /// Pickup on the pending-response row of [lifecycleFeed].
  static const String pendingPickupLabel = 'Verdun, Beirut';

  /// Pickup on the single row of [staleFeed].
  static const String stalePickupLabel = 'Bourj Hammoud, Beirut';

  /// A settled board: the snapshot came back and it has [requests] on it.
  static RequestFeedCubit ready(List<DeliveryRequest> requests) =>
      SeededRequestFeedScreenCubit(
        RequestFeedState(status: RequestFeedStatus.ready, requests: requests),
      );

  /// A settled board with nothing on it — a SUCCESSFUL read of an empty feed.
  static RequestFeedCubit emptyBoard() => SeededRequestFeedScreenCubit(
        const RequestFeedState(status: RequestFeedStatus.ready),
        repository: const EmptyRequestFeedRepository(),
      );

  /// The cold read still in flight: `GET /v1/jeebers/me/feed` has been issued
  /// and nothing has come back.
  static RequestFeedCubit coldRead() => SeededRequestFeedScreenCubit(
        const RequestFeedState(status: RequestFeedStatus.loading),
        repository: const EmptyRequestFeedRepository(),
      );

  /// The cold read FAILED with nothing on the board — the full-screen retry.
  static RequestFeedCubit loadFailed() => SeededRequestFeedScreenCubit(
        const RequestFeedState(
          status: RequestFeedStatus.error,
          error: UnknownFailure(),
        ),
        repository: const ErrorRequestFeedRepository(),
      );

  /// The cold read failed with a KIND, so the failure block's copy family and
  /// its retry-vs-exit ruling are both visible.
  static RequestFeedCubit loadFailedWith(AppFailure failure) =>
      SeededRequestFeedScreenCubit(
        RequestFeedState(status: RequestFeedStatus.error, error: failure),
        repository: KindedRequestFeedRepository(failure),
      );

  /// A settled board reached over the DEGRADED polling transport.
  static RequestFeedCubit degradedTransport(List<DeliveryRequest> requests) =>
      SeededRequestFeedScreenCubit(
        RequestFeedState(
          status: RequestFeedStatus.ready,
          transport: FeedTransport.polling,
          requests: requests,
        ),
        repository: PollingRequestFeedRepository(requests),
      );

  /// A refresh that failed while rows were already on screen.
  /// This is what `RequestFeedCubit._refresh`'s catch produces on a non-initial
  static RequestFeedCubit refreshFailedOverRows(
    List<DeliveryRequest> requests,
  ) =>
      SeededRequestFeedScreenCubit(
        RequestFeedState(
          status: RequestFeedStatus.ready,
          requests: requests,
          refreshError: const NetworkFailure(offline: true),
        ),
        repository: const ErrorRequestFeedRepository(),
      );

  /// Rows on screen plus a classified warm failure — the refresh-failed note.
  static RequestFeedCubit warmFailureOverRows(
    List<DeliveryRequest> requests,
    AppFailure failure,
  ) => WarmFailureRequestFeedScreenCubit(requests, failure);

  /// Every row above, built from one shape so the feeds differ only where the
  /// difference is the point.
  static DeliveryRequest _row({
    required String id,
    required String pickup,
    required String dropoff,
    required double distanceKm,
    required double earnings,
    JeeberRequestTier tier = JeeberRequestTier.standard,
    String currency = 'USD',
    JeeberFeedItemStatus feedStatus = JeeberFeedItemStatus.incoming,
    JeeberDeliveryAction? nextDeliveryAction,
  }) =>
      DeliveryRequest(
        id: id,
        pickup: RequestLocation(
          label: pickup,
          latitude: 33.8959,
          longitude: 35.4797,
        ),
        dropoff: RequestLocation(
          label: dropoff,
          latitude: 33.8869,
          longitude: 35.5131,
        ),
        tier: tier,
        estimatedDistanceKm: distanceKm,
        potentialEarnings: earnings,
        currency: currency,
        expiresAt: null,
        senderName: 'Sami Fawaz',
        senderRating: 4,
        itemsSummary: '1 kilo potato, water gallon, coffee blend',
        distanceFromYouKm: distanceKm,
        receivedAt: _receivedAt,
        feedStatus: feedStatus,
        nextDeliveryAction: nextDeliveryAction,
      );

  /// The Figma capture instant ("09:41"), fixed so no fixture re-renders on a
  /// clock tick.
  static DateTime get _receivedAt => DateTime.utc(2026, 6, 11, 9, 41);
}
