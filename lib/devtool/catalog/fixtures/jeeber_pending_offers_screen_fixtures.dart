// Designed states for `JeeberPendingOffersScreen` (JM-047, D15) — ONE source

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/submitted_offers_state.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offer.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offers_repository.dart';

/// The jeeber id both dev surfaces pin.
/// Not cosmetic even though nothing renders it: it is what the JM-047 dev seam
const String jeeberPendingOffersScreenJeeberId = 'user-jeeber-002';

// ─────────────────────────────────────────────────────────────────────────

/// Answers [offers] immediately. The loaded branch — and, with an empty list,
/// the empty-state branch, which is a SUCCESSFUL read that came back with
/// nothing.
class JeeberPendingOffersScreenStaticOffers
    implements SubmittedOffersRepository {
  const JeeberPendingOffersScreenStaticOffers(this.offers);

  final List<SubmittedOffer> offers;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => offers;

  @override
  Future<bool> withdraw(String offerId) async => true;
}

/// Every read throws — the COLD-load failure.
/// The cold read is the only one that reaches the full-screen error body:
/// `SubmittedOffersCubit.load` downgrades a failure to `ready` whenever
class JeeberPendingOffersScreenFailingOffers
    implements SubmittedOffersRepository {
  const JeeberPendingOffersScreenFailingOffers();

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    throw Exception('jeeber_pending_offers fixture: designed load failure');
  }

  @override
  Future<bool> withdraw(String offerId) async => false;
}

/// Never completes — the cold read is still in flight.
/// Not a hypothetical: the screen calls `load()` from its `BlocProvider.create`
/// and the first frame is painted before it can possibly return, so EVERY
class JeeberPendingOffersScreenStalledOffers
    implements SubmittedOffersRepository {
  const JeeberPendingOffersScreenStalledOffers();

  @override
  Future<List<SubmittedOffer>> listSubmitted() =>
      Completer<List<SubmittedOffer>>().future;

  @override
  Future<bool> withdraw(String offerId) => Completer<bool>().future;
}

// ─────────────────────────────────────────────────────────────────────────

/// The designed offer lists, one per state.
/// Each cast carries prices that no other cast uses, so a state accidentally
/// rewired to a neighbouring fixture is visible on screen instead of looking
class JeeberPendingOffersScreenOffers {
  const JeeberPendingOffersScreenOffers._();

  /// The reference reading: two offers still awaiting the customer's decision,
  /// one with an ETA and one without.
  static const List<SubmittedOffer> awaitingDecision = <SubmittedOffer>[
    SubmittedOffer(
      id: 'offer-1',
      requestId: 'req-101',
      price: 12.5,
      currency: 'USD',
      etaMinutes: 25,
      note: 'Can drop off at the lobby',
    ),
    SubmittedOffer(
      id: 'offer-2',
      requestId: 'req-102',
      price: 8,
      currency: 'USD',
    ),
  ];

  /// sprint-009 offer-lifecycle: the two TERMINAL outcomes beside a still-open
  /// offer.
  static const List<SubmittedOffer> mixedOutcomes = <SubmittedOffer>[
    SubmittedOffer(
      id: 'offer-3',
      requestId: 'req-103',
      price: 15,
      currency: 'USD',
      etaMinutes: 18,
      status: OfferStatus.accepted,
    ),
    SubmittedOffer(
      id: 'offer-4',
      requestId: 'req-104',
      price: 9.75,
      currency: 'USD',
      etaMinutes: 40,
      status: OfferStatus.lost,
    ),
    SubmittedOffer(
      id: 'offer-5',
      requestId: 'req-105',
      price: 11,
      currency: 'USD',
    ),
  ];

  /// A read that SUCCEEDED and came back with zero rows.
  static const List<SubmittedOffer> none = <SubmittedOffer>[];

  /// The layout ceiling, and the only cast that is not USD.
  /// Lebanese pricing is the real case: LBP is zero-decimal and everyday
  static const List<SubmittedOffer> longestContent = <SubmittedOffer>[
    SubmittedOffer(
      id: 'offer-ceiling-open',
      requestId: 'req-201',
      price: 2750000,
      currency: 'LBP',
      etaMinutes: 1440,
    ),
    SubmittedOffer(
      id: 'offer-ceiling-lost',
      requestId: 'req-202',
      price: 1875000,
      currency: 'LBP',
      etaMinutes: 2880,
      status: OfferStatus.lost,
    ),
    SubmittedOffer(
      id: 'offer-ceiling-accepted',
      requestId: 'req-203',
      price: 3200000,
      currency: 'LBP',
      status: OfferStatus.accepted,
    ),
  ];

  /// Enough rows to overflow a phone, so the list has to scroll.
  /// The screen renders `ListView.builder` and nothing else — no count, no
  static const List<SubmittedOffer> manyOffers = <SubmittedOffer>[
    SubmittedOffer(
      id: 'offer-b1',
      requestId: 'req-301',
      price: 4.25,
      currency: 'USD',
      etaMinutes: 12,
    ),
    SubmittedOffer(
      id: 'offer-b2',
      requestId: 'req-302',
      price: 5.5,
      currency: 'USD',
      etaMinutes: 20,
    ),
    SubmittedOffer(
      id: 'offer-b3',
      requestId: 'req-303',
      price: 6.75,
      currency: 'USD',
      etaMinutes: 35,
      status: OfferStatus.lost,
    ),
    SubmittedOffer(
      id: 'offer-b4',
      requestId: 'req-304',
      price: 7.8,
      currency: 'USD',
      etaMinutes: 45,
    ),
    SubmittedOffer(
      id: 'offer-b5',
      requestId: 'req-305',
      price: 13.4,
      currency: 'USD',
      etaMinutes: 60,
      status: OfferStatus.accepted,
    ),
    SubmittedOffer(
      id: 'offer-b6',
      requestId: 'req-306',
      price: 21.9,
      currency: 'USD',
      etaMinutes: 90,
    ),
  ];
}

/// Throws the CLASSIFIED failure from `listSubmitted()`, so the failure block
/// shows the kind's copy family rather than the generic one.
class FailingSubmittedOffersRepository implements SubmittedOffersRepository {
  const FailingSubmittedOffersRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => throw failure;

  @override
  Future<bool> withdraw(String offerId) async => throw failure;
}

class ReadThenFailSubmittedOffersRepository
    implements SubmittedOffersRepository {
  ReadThenFailSubmittedOffersRepository(this.offers, this.failure);
  final List<SubmittedOffer> offers;
  final AppFailure failure;
  int reads = 0;
  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    if (++reads > 1) throw failure;
    return offers;
  }

  @override
  Future<bool> withdraw(String offerId) async => throw failure;
}

/// Lists fine, but every withdraw throws — the UX-04 snack rung.
class WithdrawFailingSubmittedOffersRepository
    implements SubmittedOffersRepository {
  const WithdrawFailingSubmittedOffersRepository(this.offers, this.failure);

  final List<SubmittedOffer> offers;
  final AppFailure failure;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async => offers;

  @override
  Future<bool> withdraw(String offerId) async => throw failure;
}

/// Rows on screen plus a warm failure — the refresh-failed note.
class RefreshFailedSubmittedOffersCubit extends SubmittedOffersCubit {
  RefreshFailedSubmittedOffersCubit(
    List<SubmittedOffer> offers,
    AppFailure failure,
  ) : super(repository: JeeberPendingOffersScreenStaticOffers(offers)) {
    emit(
      SubmittedOffersState(
        status: SubmittedOffersStatus.ready,
        offers: offers,
        refreshError: failure,
      ),
    );
  }
}

/// Builder form, matching the other fixture entry points in this file.
SubmittedOffersCubit refreshFailedSubmittedOffersCubit(
  List<SubmittedOffer> offers,
  AppFailure failure,
) => RefreshFailedSubmittedOffersCubit(offers, failure);
