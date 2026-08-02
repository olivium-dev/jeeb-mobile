// Designed states for the Jeeber dashboard (`JeeberHomeScreen`) — ONE source of
// truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_04_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/jeeber_home/presentation/jeeber_home_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog entry owned these fakes privately, so the previews would have had
// to re-declare them and the two would have drifted the first time a fixture
// changed. Everything either consumer needs to reach a designed state lives
// here instead; each consumer supplies only its own host chrome (the catalog
// mounts the screen straight into the catalog page, the preview host frames it
// to a device box inside the [Scaffold] `jeebPreviewHost` already supplies).
//
// NOTHING here touches the network. Every gateway/repository below answers from
// a const list, throws, or never completes, and every cubit is either seeded in
// its constructor or driven only by the screen's own mount-time `load()`. The
// `CatalogNetworkGuard` both hosts install is a net, not the plan.
//
// Two collaborators are deliberately inert rather than merely fake:
//
//  * [AvailabilityCubit.tickerFactory] defaults to `Stream.periodic(1 min)`,
//    and the cubit subscribes to it the moment the jeeber is online. That is a
//    pending timer that fails every widget test which mounts this screen, so
//    every cubit built here gets an empty ticker.
//  * [RequestFeedCubit.start] opens three subscriptions and a 1 s expiry sweep.
//    [SeededRequestFeedCubit] never calls it — it emits its one frame in the
//    constructor instead — so the feed renders with no timer behind it.

import 'dart:async';

import '../../../features/chat/domain/accepted_conversation.dart';
import '../../../features/jeeber_home/application/availability_cubit.dart';
import '../../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_state.dart';
import '../../../features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offer.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offers_repository.dart';

/// Availability gateway whose cold `fetch()` never resolves, freezing the cubit
/// on [AvailabilityLoadPhase.loading] for as long as the host is open.
///
/// A [Completer] that is never completed holds no timer and no subscription; it
/// simply never settles — which is exactly what a `GET /v1/availability` on a
/// dead-air connection looks like before the transport times out.
class StalledAvailabilityGateway implements AvailabilityGateway {
  const StalledAvailabilityGateway();

  @override
  Future<AvailabilityStatus> fetch() => Completer<AvailabilityStatus>().future;

  @override
  Future<AvailabilityStatus> toggle({required bool goOnline}) =>
      Completer<AvailabilityStatus>().future;
}

/// A submitted-offers fake that never lists anything.
///
/// [SubmittedOffersCubit] only calls `load()` lazily when the feed's
/// Pending-Response sub-tab is first selected, so this keeps that path
/// fake-backed with zero network regardless of whether GetIt happens to be
/// configured in the host app. Without it the screen's own
/// `_resolveSubmittedOffersCubit` falls through to `sl<Dio>()`.
class EmptySubmittedOffersRepository implements SubmittedOffersRepository {
  const EmptySubmittedOffersRepository();

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => const <SubmittedOffer>[];

  @override
  Future<bool> withdraw(String offerId) async => true;
}

/// Answers one canned list of won orders, with no latency.
///
/// Filling [JeeberActiveDeliveriesBanner.repository] with this is what stops
/// the banner resolving `sl<Dio>()` and issuing `GET /requests?role=jeeber`.
class CannedAcceptedConversationsRepository
    implements AcceptedConversationsRepository {
  const CannedAcceptedConversationsRepository(this.accepted);

  final List<AcceptedConversation> accepted;

  @override
  Future<List<AcceptedConversation>> fetchAccepted() async => accepted;
}

/// [RequestFeedCubit] pinned to one frame.
///
/// Never `start()`ed, so none of its three live subscriptions and neither of
/// its timers exist. The repository is the in-memory
/// [SeededRequestFeedRepository] holding the SAME snapshot, so the
/// pull-to-refresh the screen wires up replays the fixture instead of reaching
/// `GET /v1/jeebers/me/feed`.
class SeededRequestFeedCubit extends RequestFeedCubit {
  SeededRequestFeedCubit(List<DeliveryRequest> requests)
    : super(repository: SeededRequestFeedRepository(requests)) {
    emit(
      RequestFeedState(status: RequestFeedStatus.ready, requests: requests),
    );
  }
}

/// The designed states of `JeeberHomeScreen`, as collaborators + copy.
///
/// Deliberately NOT a widget builder: the two consumers need different chrome
/// around the same screen, and a shared builder that took a `frameToDevice`
/// flag would just be two builders wearing one name.
class JeeberHomeScreenPreviewFixtures {
  const JeeberHomeScreenPreviewFixtures._();

  /// The signed-in jeeber's display name, as the dashboard greeting receives
  /// it. `JeeberHomeGreeting` greets the FIRST token only.
  static const String profileName = 'Kamal';

  /// A name long enough to contest the greeting row at 320 pt, paired with
  /// [longestContentFeed].
  static const String longProfileName = 'Abdulrahman Al-Muhandis Al-Trabulsi';

  /// The customer on the one won order in [wonOrders] — the row the
  /// active-work disclosure headlines.
  static const String wonCounterpartName = 'Rania Kassem';

  /// The customer on the order an `offer_accepted` push has just returned,
  /// used by the state where the feed is still non-empty ([justWonOrder]).
  static const String justWonCounterpartName = 'Ziad Chamoun';

  /// The client on the ceiling row in [longestContentFeed].
  static const String longestSenderName = 'Abdulrahman Al-Muhandis Al-Trabulsi';

  /// Cold start resolves to OFFLINE — the state a jeeber who has not tapped
  /// the toggle since launch lands in, and the catalog's "State 2, offline".
  static AvailabilityCubit offlineAvailability() =>
      _availability(InMemoryAvailabilityGateway());

  /// Cold start resolves to ONLINE — the jeeber is on the matching engine.
  static AvailabilityCubit onlineAvailability() => _availability(
    InMemoryAvailabilityGateway(
      initial: const AvailabilityStatus(
        state: AvailabilityState.online,
        activeDeliveryCount: 0,
      ),
    ),
  );

  /// Cold start throws — the full-screen retry state, and the 403 the
  /// JEBV4-271/279 auto-activation exists to self-heal.
  static AvailabilityCubit failingAvailability() =>
      _availability(InMemoryAvailabilityGateway(respondWithError: true));

  /// Cold start never returns — the screen's in-flight frame.
  static AvailabilityCubit stalledAvailability() =>
      _availability(const StalledAvailabilityGateway());

  /// The cubit backing the feed's Pending-Response sub-tab. Passed as the
  /// screen's `submittedOffersCubitFactory`, which owns and closes it.
  static SubmittedOffersCubit submittedOffersCubit() =>
      SubmittedOffersCubit(repository: const EmptySubmittedOffersRepository());

  /// One live auction on the board — the Figma screen-24 row, verbatim.
  static List<DeliveryRequest> incomingFeed() => DevJeeberFeedFixtures.incoming();

  /// The layout ceiling: a client name that cannot fit on one line and a
  /// real-world food order as the description.
  static List<DeliveryRequest> longestContentFeed() => <DeliveryRequest>[
    DeliveryRequest(
      id: 'jeeber-home-longest',
      pickup: const RequestLocation(
        label: 'Spinneys Dbayeh',
        latitude: 33.8,
        longitude: 35.5,
      ),
      dropoff: const RequestLocation(
        label: 'Building 12, Rue Verdun, Achrafieh, Beirut',
        latitude: 33.9,
        longitude: 35.6,
      ),
      tier: JeeberRequestTier.standard,
      estimatedDistanceKm: 12.5,
      potentialEarnings: 14,
      currency: 'USD',
      expiresAt: _farFuture,
      senderName: longestSenderName,
      senderRating: 4,
      itemsSummary:
          '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
          'large fries — call me when you arrive at the building entrance, '
          'third floor, ring twice',
      distanceFromYouKm: 12.5,
      receivedAt: _receivedAt,
      feedStatus: JeeberFeedItemStatus.incoming,
    ),
  ];

  /// A feed cubit already holding [requests], with no live subscription.
  static RequestFeedCubit feed(List<DeliveryRequest> requests) =>
      SeededRequestFeedCubit(requests);

  /// A feed cubit whose snapshot came back EMPTY — a successful read of an
  /// empty board, not a failed one (the feed has no failure surface at all).
  static RequestFeedCubit emptyFeed() =>
      SeededRequestFeedCubit(const <DeliveryRequest>[]);

  /// The jeeber has one accepted order in progress.
  static CannedAcceptedConversationsRepository wonOrders() =>
      const CannedAcceptedConversationsRepository(<AcceptedConversation>[
        AcceptedConversation(
          conversationId: 'conv-jeeber-home-9001',
          requestId: 'req-jeeber-home-9001',
          counterpartName: wonCounterpartName,
          displayId: 'ORD-23748',
          destinationLabel: 'Achrafieh, Beirut',
        ),
      ]);

  /// The order the `offer_accepted` push has just returned, while the feed the
  /// jeeber is looking at is still non-empty.
  static CannedAcceptedConversationsRepository justWonOrder() =>
      const CannedAcceptedConversationsRepository(<AcceptedConversation>[
        AcceptedConversation(
          conversationId: 'conv-jeeber-home-9002',
          requestId: 'req-jeeber-home-9002',
          counterpartName: justWonCounterpartName,
          displayId: 'ORD-23749',
          destinationLabel: 'Jnah, Beirut',
        ),
      ]);

  /// Far enough out that nothing here expires by accident — these fixtures
  /// never run the cubit's expiry sweep, so the deadline is inert either way.
  static DateTime get _farFuture => DateTime.utc(2030);

  /// The Figma capture instant ("09:41"), as a fixed value so neither host
  /// re-renders on a clock tick.
  static DateTime get _receivedAt => DateTime.utc(2026, 6, 11, 9, 41);

  /// Every availability cubit these fixtures hand out: real cubit, fake
  /// gateway, and an empty inactivity ticker so the 8 h auto-offline rule
  /// never schedules a timer behind a preview or a catalog page.
  static AvailabilityCubit _availability(AvailabilityGateway gateway) =>
      AvailabilityCubit(gateway: gateway, tickerFactory: _noTicker);

  static Stream<DateTime> _noTicker() => const Stream<DateTime>.empty();
}
