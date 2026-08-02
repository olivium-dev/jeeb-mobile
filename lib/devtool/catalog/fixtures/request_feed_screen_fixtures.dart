// Designed states for the Jeeber request feed (`RequestFeedScreen`) — ONE
// source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_05_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/jeeber_request_feed/presentation/request_feed_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog entry owned the three fake repositories privately, so the preview
// section would have had to re-declare them and the two would have drifted the
// first time a fixture changed. Everything either consumer needs to reach a
// designed state lives here instead; each supplies only its own host chrome (the
// catalog mounts the screen into a catalog page and drives a REAL
// `RequestFeedCubit.start()`; the preview host frames it to a device box and
// seeds an inert cubit — see "Two ways to drive it" below).
//
// NOTHING here touches the network. Every repository answers from a const list
// or throws, and every cubit handed out by [RequestFeedScreenPreviewFixtures] is
// seeded in its constructor rather than started. The `CatalogNetworkGuard` both
// hosts install is a net, not the plan.
//
// ## Two ways to drive it, and why both exist
//
// [RequestFeedCubit.start] opens three subscriptions and a 1 s expiry sweep, and
// reaches the designed state only by way of a real `refresh()` round trip. That
// is what the catalog wants — a live screen a designer can pull-to-refresh and
// tap — and it is exactly what a preview canvas and a widget test do not want.
// So the repositories below serve the catalog, and [SeededRequestFeedScreenCubit]
// serves the previews by emitting one designed [RequestFeedState] in its
// constructor with no subscription and no timer behind it.
//
// The two paths agree on the data because they share it: the catalog's snapshot
// repositories are built over the same feed lists the seeded cubit emits.
//
// ## Deadlines are deliberately absent from most feeds
//
// `DeliveryRequest.expiresAt` is turned into a countdown against
// `DateTime.now()` by the screen, so any fixture that carries one renders a
// number that changes every second and differs on every run. The feeds below
// therefore pass `expiresAt: null` — which is a real gateway shape, documented
// on the model as "no countdown applies to this row" — except where the
// countdown itself is the thing under review, which is what
// [RequestFeedScreenPreviewFixtures.incomingFeed] (the catalog's Figma screen-24
// row, verbatim) already covers.

import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';

/// Answers every snapshot with an empty board and never pushes.
///
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
///
/// Never `start()`ed, so none of its three live subscriptions exist and neither
/// the expiry sweep nor the deferred-refresh gate is ever constructed (both are
/// `late final` and only `start()`/`close()` touch them). The repository behind
/// it is still real enough to answer the pull-to-refresh the screen wires up —
/// that is what [seed] carries — so a reviewer who pulls the list in the canvas
/// replays the fixture instead of reaching `GET /v1/jeebers/me/feed`.
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

/// The designed states of `RequestFeedScreen`, as feeds + inert cubits.
///
/// Deliberately NOT a widget builder: the catalog needs a live, startable cubit
/// inside its own stateful host and the previews need a frozen one inside a
/// device-sized box, and a shared builder taking a `live` flag would just be two
/// builders wearing one name.
abstract final class RequestFeedScreenPreviewFixtures {
  /// The Figma screen-24 row, verbatim (`dev-feed-incoming`) — the catalog's
  /// "Incoming — Ignore / Offer card" state.
  ///
  /// Carries the dev fixture's far-future `expiresAt`, so this is the one feed
  /// whose countdown badge is live.
  static List<DeliveryRequest> incomingFeed() => DevJeeberFeedFixtures.incoming();

  /// The Figma screen-25 row — the jeeber has offered and is awaiting a reply.
  static List<DeliveryRequest> pendingFeed() => DevJeeberFeedFixtures.pending();

  /// The Figma screen-26 rows — accepted, each with its next delivery action.
  static List<DeliveryRequest> acceptedFeed() => DevJeeberFeedFixtures.replies();

  /// One row per [JeeberFeedItemStatus] bucket, each with its own pickup so the
  /// three can be told apart on screen — which is the whole question this feed
  /// is here to answer.
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
  /// market's normal case rather than an edge case.
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
          errorMessageKey: 'requestFeedErrorLoad',
        ),
        repository: const ErrorRequestFeedRepository(),
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
  ///
  /// This is what `RequestFeedCubit._refresh`'s catch produces on a non-initial
  /// read: the status stays `ready` because the feed is non-empty, and the
  /// failure is recorded ONLY in `errorMessageKey`.
  static RequestFeedCubit refreshFailedOverRows(
    List<DeliveryRequest> requests,
  ) =>
      SeededRequestFeedScreenCubit(
        RequestFeedState(
          status: RequestFeedStatus.ready,
          requests: requests,
          errorMessageKey: 'requestFeedErrorLoad',
        ),
        repository: const ErrorRequestFeedRepository(),
      );

  /// Every row above, built from one shape so the feeds differ only where the
  /// difference is the point.
  ///
  /// `expiresAt` is null by default: see the file header — a live deadline makes
  /// the countdown badge, and therefore every rendering of the card, depend on
  /// the wall clock.
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
