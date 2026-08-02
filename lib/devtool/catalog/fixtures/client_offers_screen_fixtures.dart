// Designed states for `ClientOffersScreen` (JM-028 offer-review-list) — ONE
// source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_02_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/client_offers/presentation/
//     client_offers_screen.dart                         the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's five states were hand-built inside the entry file (a private
// `_FailingOffersRepository`, a private cubit factory, and `FakeOffersRepository`
// with its `Random(7)` + `DateTime.now()` seed). They moved here whole when the
// screen got a preview section, because two copies of the same "designed state"
// drift and the catalog is the one a designer signs off against.
//
// Two things changed in the move, both to make the states REVIEWABLE rather
// than merely renderable:
//
//  * **The clock is frozen** ([clock]). Every window deadline is expressed as an
//    offset from it and [inertCubit] pins the cubit's `now` to the same instant,
//    so `Window: 4:30 left` is exactly 4:30 in the canvas, in a render test and
//    on a designer's device — instead of 4:29-and-a-bit, which no test can pin.
//  * **The bids are named, not generated.** `FakeOffersRepository._defaultSeed`
//    built three offers from a seeded `Random` and `DateTime.now()`; each state
//    below now carries its OWN cast, so a preview accidentally rewired to a
//    neighbouring fixture is visible instead of looking identical.
//
// NOTHING here touches the network. Every repository answers from a const list,
// throws, or never completes, and [inertCubit] hands the cubit two EMPTY streams
// in place of its push-refresh bus and its 1 s countdown ticker — so no fixture
// can arm a timer or a subscription either. The `CatalogNetworkGuard` both hosts
// install is a net, not the plan.
//
// Avatar urls stay NULL throughout: a non-null url makes `OmdsProfileAvatar`
// build a `NetworkImage`, which is a real HTTP GET that the guard would happily
// allow (it only rejects mutating verbs).

import 'dart:async';

import '../../../features/cancel_request/data/fake_cancel_request_repository.dart';
import '../../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../../features/client_offers/application/client_offers_cubit.dart';
import '../../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../../features/client_offers/domain/offer.dart';
import '../../../features/client_offers/domain/offers_repository.dart';

/// Answers ONE canned [OffersSnapshot], with no latency and no drip-feed.
///
/// The shipped [FakeOffersRepository] cannot express two of the states below —
/// it has no way to set `requestIsExpired`, and its default seed is generated
/// rather than named — so the fixtures own this one instead. [acceptOffer]
/// mirrors the fake's behaviour so a designer who taps Accept → Confirm in the
/// Screen Catalog still lands on the order-chat route.
class SeededOffersRepository implements OffersRepository {
  SeededOffersRepository({
    required this.offers,
    this.windowExpiresAt,
    this.requestIsOpen = true,
    this.requestIsExpired = false,
  });

  final List<Offer> offers;
  final DateTime? windowExpiresAt;
  final bool requestIsExpired;

  /// Mutable: accepting an offer closes the request, exactly as the gateway
  /// does, so a second accept in the same session fails the way the real one
  /// would.
  bool requestIsOpen;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async => OffersSnapshot(
        offers: List<Offer>.unmodifiable(offers),
        windowExpiresAt: windowExpiresAt,
        requestIsOpen: requestIsOpen,
        requestIsExpired: requestIsExpired,
      );

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    if (!requestIsOpen) {
      throw const OffersRepositoryException(OffersFailure.requestNotOpen);
    }
    if (offers.every((Offer o) => o.id != offerId)) {
      throw const OffersRepositoryException(OffersFailure.offerNotPending);
    }
    requestIsOpen = false;
    return OfferAcceptResult(
      deliveryId: requestId,
      conversationId: 'conv-for-$requestId',
    );
  }
}

/// Every read throws [OffersFailure.network] — the COLD-load failure.
///
/// The cold read is the only one that reaches the full-screen error body:
/// `ClientOffersCubit.refresh` is non-destructive and keeps the rendered list,
/// so a repository that failed on the second read would still show the cards.
/// That distinction is what [ColdOkThenFailingOffersRepository] is for.
class FailingOffersRepository implements OffersRepository {
  const FailingOffersRepository();

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    throw const OffersRepositoryException(OffersFailure.network);
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    throw const OffersRepositoryException(OffersFailure.network);
  }
}

/// The COLD read succeeds; every read after it throws [failure].
///
/// This is the only way to reach the INLINE error banner over a live list —
/// `_LoadedBody` renders it from `state.error` while `status` is still `loaded`,
/// which no cold-load fixture can produce.
class ColdOkThenFailingOffersRepository implements OffersRepository {
  ColdOkThenFailingOffersRepository({
    required this.cold,
    this.failure = OffersFailure.unknown,
  });

  final OffersSnapshot cold;
  final OffersFailure failure;

  int reads = 0;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    if (reads++ == 0) return cold;
    throw OffersRepositoryException(failure);
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    throw OffersRepositoryException(failure);
  }
}

/// A read that never resolves, freezing the screen on
/// [OffersScreenStatus.loading] for as long as the host is open.
///
/// A [Completer] that is never completed holds no timer and no subscription; it
/// simply never settles.
class StalledOffersRepository implements OffersRepository {
  StalledOffersRepository();

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) =>
      Completer<OffersSnapshot>().future;

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) =>
      Completer<OfferAcceptResult>().future;
}

/// The designed states of `ClientOffersScreen`, as repositories plus the cubit
/// factory that keeps them inert.
///
/// The screen takes a REPOSITORY, not a state — it builds its own
/// [ClientOffersCubit] and calls `load()` at mount — so a state is described
/// here by what the repository answers, and the real cold-load path runs in the
/// catalog and in the canvas exactly as it does in production.
class ClientOffersScreenPreviewFixtures {
  const ClientOffersScreenPreviewFixtures._();

  /// The request every state hangs off. Kept as one constant because the fake
  /// accept derives the conversation id from it (`conv-for-<requestId>`).
  static const String requestId = 'req-demo-1';

  /// Frozen "now" for every window deadline AND for the cubit's own clock, so
  /// the countdown band renders an exact, pinnable string.
  static final DateTime clock = DateTime.utc(2026, 5, 17, 12);

  /// The cubit the screen would build for itself, with its two live streams
  /// replaced by empty ones.
  ///
  /// Both matter. `refreshSignals` is the b02 wave-C push→refetch bus, which in
  /// a preview would resolve out of the DI graph; `clockTicks` defaults to a
  /// `Stream.periodic(1s)` whose subscription is a PENDING TIMER — enough on its
  /// own to fail every widget test that mounts this screen. `now` is pinned to
  /// [clock] so `windowRemaining` is deterministic.
  static ClientOffersCubit inertCubit(
    OffersRepository repository,
    String requestId,
  ) {
    return ClientOffersCubit(
      repository: repository,
      requestId: requestId,
      now: () => clock,
      refreshSignals: const Stream<void>.empty(),
      clockTicks: const Stream<void>.empty(),
    );
  }

  /// [inertCubit] plus ONE pull-to-refresh after the cold load resolves.
  ///
  /// Pair it with [refreshFails]. The screen's own `create` calls `load()` too;
  /// the second call is a no-op (`load` returns unless the status is
  /// `initial`/`failed`), so the sequence is exactly one cold read followed by
  /// one refresh — the same two calls a customer produces by pulling the list
  /// down while the network is flaky.
  static ClientOffersCubit refreshFailureCubit(
    OffersRepository repository,
    String requestId,
  ) {
    final ClientOffersCubit cubit = inertCubit(repository, requestId);
    unawaited(cubit.load().then((_) => cubit.refresh()));
    return cubit;
  }

  /// The JM-030 cancel sheet's repository. The sheet resolves its own from DI
  /// when this is null, which in a preview means reaching into an unbuilt
  /// graph — so both hosts hand it a local fake even though only a TAP can
  /// open the sheet.
  static CancelRequestRepository cancelRepository() =>
      FakeCancelRequestRepository();

  /// One bid, with the fields the card actually renders.
  ///
  /// `submittedAt` is derived from [clock] so the newest-first tie-break between
  /// two equal fees is stable across runs.
  static Offer bid({
    required String id,
    required String jeeberName,
    required double fee,
    required int etaMinutes,
    required JeeberVehicle vehicle,
    double rating = 0,
    int ratingCount = 0,
    String currency = 'USD',
    String? note,
    Duration age = Duration.zero,
  }) {
    return Offer(
      id: id,
      jeeberId: 'jeeber-$id',
      jeeberName: jeeberName,
      fee: fee,
      currency: currency,
      etaMinutes: etaMinutes,
      vehicle: vehicle,
      rating: rating,
      ratingCount: ratingCount,
      submittedAt: clock.subtract(age),
      note: note,
    );
  }

  // ────────────────────────────── the casts ───────────────────────────────

  /// Three bids that between them cover the card's three identity readings: a
  /// well-rated Jeeber, one with a note attached, and a brand-new account with
  /// zero ratings (SW-08 renders "No ratings yet", never a fabricated "0.0 (0)").
  ///
  /// Fees ascend in the default sort order, so the list reads Karim → Hadi →
  /// Rana and the price sort is verifiable by eye.
  static List<Offer> get threeBids => <Offer>[
        bid(
          id: 'bid-karim',
          jeeberName: 'Karim Nassar',
          fee: 4.5,
          etaMinutes: 12,
          vehicle: JeeberVehicle.scooter,
          rating: 4.8,
          ratingCount: 214,
        ),
        bid(
          id: 'bid-hadi',
          jeeberName: 'Hadi Chalhoub',
          fee: 6,
          etaMinutes: 8,
          vehicle: JeeberVehicle.motorcycle,
          rating: 4.6,
          ratingCount: 87,
          note: 'Two streets away, I can pick up right now.',
          age: const Duration(seconds: 40),
        ),
        bid(
          id: 'bid-rana',
          jeeberName: 'Rana Ayoub',
          fee: 9.25,
          etaMinutes: 20,
          vehicle: JeeberVehicle.car,
          age: const Duration(seconds: 95),
        ),
      ];

  /// The single bid on the locally-elapsed-window state.
  static List<Offer> get elapsedWindowBids => <Offer>[
        bid(
          id: 'bid-ziad',
          jeeberName: 'Ziad Mansour',
          fee: 5.75,
          etaMinutes: 16,
          vehicle: JeeberVehicle.motorcycle,
          rating: 4.4,
          ratingCount: 61,
        ),
      ];

  /// The single bid on the closed-request state.
  static List<Offer> get closedRequestBids => <Offer>[
        bid(
          id: 'bid-nour',
          jeeberName: 'Nour Haddad',
          fee: 7.5,
          etaMinutes: 24,
          vehicle: JeeberVehicle.bicycle,
          rating: 4.2,
          ratingCount: 9,
        ),
      ];

  /// The single bid on the server-expired state.
  static List<Offer> get serverExpiredBids => <Offer>[
        bid(
          id: 'bid-fadi',
          jeeberName: 'Fadi Younes',
          fee: 8,
          etaMinutes: 30,
          vehicle: JeeberVehicle.van,
          rating: 4.9,
          ratingCount: 143,
        ),
      ];

  /// The single bid the refresh-failure state keeps on screen UNDER the banner.
  /// Its presence is the contract: a failed refresh must not clear a list the
  /// customer can still act on.
  static List<Offer> get refreshFailureBids => <Offer>[
        bid(
          id: 'bid-layal',
          jeeberName: 'Layal Kassem',
          fee: 5,
          etaMinutes: 14,
          vehicle: JeeberVehicle.scooter,
          rating: 4.7,
          ratingCount: 38,
        ),
      ];

  /// The layout ceiling: the longest plausible name, a non-USD fee wide enough
  /// to clip the `maxLines: 1` pill, a nine-figure rating count and a note past
  /// its three-line limit — above a bid whose `jeeberName` is a raw UUID, which
  /// the un-enriched gateway row really does deliver (SW-08) and which the card
  /// must suppress.
  ///
  /// The fees are ordered so the CEILING card sorts first (price ascending is
  /// the default): a preview whose one interesting card is below the fold is a
  /// preview of a scrollbar.
  static List<Offer> get longestContentBids => <Offer>[
        bid(
          id: 'bid-long',
          jeeberName: 'Alexander Bartholomew Montgomery the Third',
          fee: 1234567.89,
          currency: 'LBP',
          etaMinutes: 90,
          vehicle: JeeberVehicle.van,
          rating: 4.9,
          ratingCount: 1234567890,
          note: 'I am two streets away and can take the parcel right now, but '
              'the building has no lift so please meet me at the door on the '
              'ground floor.',
        ),
        bid(
          id: 'bid-uuid',
          jeeberName: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
          fee: 1335000,
          currency: 'LBP',
          etaMinutes: 45,
          vehicle: JeeberVehicle.walker,
          age: const Duration(seconds: 20),
        ),
      ];

  // ───────────────────────────── the states ───────────────────────────────

  /// Catalog "Loaded — 3 offers": an open request, three bids, 4:30 left on the
  /// display window.
  static OffersRepository freshWindow() => SeededOffersRepository(
        offers: threeBids,
        windowExpiresAt: clock.add(const Duration(minutes: 4, seconds: 30)),
      );

  /// Catalog "Empty — no offers yet": a successful read that came back with ZERO
  /// rows while the window is still wide open.
  static OffersRepository noBidsYet() => SeededOffersRepository(
        offers: const <Offer>[],
        windowExpiresAt: clock.add(const Duration(minutes: 9, seconds: 12)),
      );

  /// Catalog "Offer window expired": the DISPLAY deadline has passed locally
  /// while the gateway still reports the request open.
  ///
  /// Note what this is not: `requestIsExpired` stays false, because only a
  /// terminal server snapshot sets it (`client_offers_state.dart`: "Local
  /// countdown progress never sets this lifecycle flag"). See [serverExpired]
  /// for the other half of the pair.
  static OffersRepository elapsedWindow() => SeededOffersRepository(
        offers: elapsedWindowBids,
        windowExpiresAt: clock.subtract(const Duration(minutes: 1)),
      );

  /// Catalog "Request closed": the gateway has matched / cancelled the request,
  /// with no window deadline in the snapshot.
  static OffersRepository closedRequest() => SeededOffersRepository(
        offers: closedRequestBids,
        requestIsOpen: false,
      );

  /// Catalog "Error — network": the cold read fails.
  static OffersRepository failingLoad() => const FailingOffersRepository();

  /// The terminal server verdict: `requestIsExpired` AND `requestIsOpen: false`,
  /// which is the only shape that renders the "Offer window expired" band.
  static OffersRepository serverExpired() => SeededOffersRepository(
        offers: serverExpiredBids,
        requestIsOpen: false,
        requestIsExpired: true,
      );

  /// The cold read never resolves — the screen's loading body.
  static OffersRepository stalledLoad() => StalledOffersRepository();

  /// Cold load succeeds, the pull-to-refresh behind it fails. Drive it with
  /// [refreshFailureCubit].
  static OffersRepository refreshFails() => ColdOkThenFailingOffersRepository(
        cold: OffersSnapshot(
          offers: refreshFailureBids,
          windowExpiresAt: clock.add(const Duration(minutes: 2)),
          requestIsOpen: true,
        ),
      );

  /// The layout ceiling, on the 24 h window the gateway falls back to when a
  /// request's tier does not resolve (`TierExpiryWindowResolver.SafeExpiryWindow`
  /// — the input that once printed `1433:18 left` on real hardware).
  static OffersRepository longestContent() => SeededOffersRepository(
        offers: longestContentBids,
        windowExpiresAt: clock.add(
          const Duration(hours: 23, minutes: 53, seconds: 18),
        ),
      );
}
