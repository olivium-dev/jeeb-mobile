// Designed states for `ClientOffersScreen` (JM-028 offer-review-list) — ONE

import 'dart:async';

import '../../../features/cancel_request/data/fake_cancel_request_repository.dart';
import '../../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../../features/client_offers/application/client_offers_cubit.dart';
import '../../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../../features/client_offers/domain/offer.dart';
import '../../../features/client_offers/domain/offers_repository.dart';

/// Answers ONE canned [OffersSnapshot], with no latency and no drip-feed.
/// The shipped [FakeOffersRepository] cannot express two of the states below —
/// it has no way to set `requestIsExpired`, and its default seed is generated
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
/// The cold read is the only one that reaches the full-screen error body:
/// `ClientOffersCubit.refresh` is non-destructive and keeps the rendered list,
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
/// This is the only way to reach the INLINE error banner over a live list —
/// `_LoadedBody` renders it from `state.error` while `status` is still `loaded`,
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
/// A [Completer] that is never completed holds no timer and no subscription; it
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
/// The screen takes a REPOSITORY, not a state — it builds its own
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
  /// Pair it with [refreshFails]. The screen's own `create` calls `load()` too;
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
  static CancelRequestRepository cancelRepository() =>
      FakeCancelRequestRepository();

  /// One bid, with the fields the card actually renders.
  /// `submittedAt` is derived from [clock] so the newest-first tie-break between
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
  static OffersRepository longestContent() => SeededOffersRepository(
        offers: longestContentBids,
        windowExpiresAt: clock.add(
          const Duration(hours: 23, minutes: 53, seconds: 18),
        ),
      );
}
