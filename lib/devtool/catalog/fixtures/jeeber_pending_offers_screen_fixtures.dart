// Designed states for `JeeberPendingOffersScreen` (JM-047, D15) — ONE source
// of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_05_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/jeeber_pending_offers/presentation/
//     jeeber_pending_offers_screen.dart                 the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's four states were hand-built inside the entry file: one private
// `_StaticSubmittedOffersRepository` with a `throwOnList` flag, and four inline
// `SubmittedOffer` lists. They moved here whole when the screen got a preview
// section, because two copies of the same "designed state" drift and the
// catalog is the one a designer signs off against.
//
// Nothing changed in the move except the shape of the fakes: one repository
// with a boolean became three, each named after the branch it drives, so a
// state can no longer be read as "static, probably fine" when it is really the
// error path. The four casts are the same offers, at the same prices, under the
// same ids — [awaitingDecision], [mixedOutcomes] and [none] are verbatim.
//
// Two casts are NEW and belong only to the preview canvas, which reviews states
// the catalog does not carry:
//
//   [longestContent]  the layout ceiling — the widest money string the app can
//                     produce (LBP is zero-decimal and runs to seven digits)
//                     beside the widest plausible ETA, on the narrowest phone.
//   [manyOffers]      enough rows to make the list scroll, which is the only
//                     way to see that this screen has no count, no header and
//                     no bottom affordance of any kind.
//
// NOTHING here touches the network. Every repository answers from a `const`
// list, throws, or never completes — the `CatalogNetworkGuard` both hosts
// install is a net, not the plan. There is no Dio, no GetIt and no
// `DioSubmittedOffersRepository` on any path below.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import '../../../features/jeeber_request_feed/domain/submitted_offer.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offers_repository.dart';

/// The jeeber id both dev surfaces pin.
///
/// Not cosmetic even though nothing renders it: it is what the JM-047 dev seam
/// (`jeeb.seam.journey=jeeber_pending_offers`) pins and what the Maestro flow
/// queries (`?jeeberId=user-jeeber-002`), so a mocked state that used a
/// different id would stop matching the flow it is supposed to illustrate.
const String jeeberPendingOffersScreenJeeberId = 'user-jeeber-002';

// ─────────────────────────────────────────────────────────────────────────
// Repositories — three outcomes, no network
// ─────────────────────────────────────────────────────────────────────────

/// Answers [offers] immediately. The loaded branch — and, with an empty list,
/// the empty-state branch, which is a SUCCESSFUL read that came back with
/// nothing.
///
/// [withdraw] reports success, so tapping Withdraw in either dev surface
/// removes the row optimistically exactly as the gateway path would. There is
/// no re-read behind it: the cubit drops the row locally and the next `load()`
/// answers from the same const list, so the row comes BACK on pull-to-refresh.
/// That is a property of the fixture, not of the screen.
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
///
/// The cold read is the only one that reaches the full-screen error body:
/// `SubmittedOffersCubit.load` downgrades a failure to `ready` whenever
/// `offers` is non-empty, so a repository that failed on the SECOND read would
/// keep showing the rows with no error surface at all. The error state is
/// therefore reachable only from an empty list, which is what this fake is.
///
/// [withdraw] returns false — the "keeps the row so the jeeber can retry"
/// branch the widget tests assert.
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
///
/// Not a hypothetical: the screen calls `load()` from its `BlocProvider.create`
/// and the first frame is painted before it can possibly return, so EVERY
/// jeeber sees this state. A [Completer] that is never completed holds no timer
/// and no subscription, so it settles under `pumpAndSettle` like any static
/// widget — the spinner it puts on screen does not, which is why the preview
/// that uses this fake mutes its ticker.
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
// Casts
// ─────────────────────────────────────────────────────────────────────────

/// The designed offer lists, one per state.
///
/// Each cast carries prices that no other cast uses, so a state accidentally
/// rewired to a neighbouring fixture is visible on screen instead of looking
/// plausible.
class JeeberPendingOffersScreenOffers {
  const JeeberPendingOffersScreenOffers._();

  /// The reference reading: two offers still awaiting the customer's decision,
  /// one with an ETA and one without.
  ///
  /// `offer-1` carries a [SubmittedOffer.note]. Nothing renders it —
  /// [PendingOfferRow] draws price, ETA, status and the Withdraw control and
  /// never reads `note` — so this cast is also the evidence that the note a
  /// jeeber typed on the offer-submission screen is not shown back to them
  /// anywhere on this surface.
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
  ///
  /// The branch that must never regress — a terminal row shows an outcome badge
  /// and NO Withdraw control, because withdrawing an accepted offer would ask
  /// the gateway to delete a bid that has already become a delivery. It is also
  /// the cast that shows the two row heights this list mixes: measured at
  /// 390 pt, a terminal row is 89 dp and an open one 141 (129 against 181 at
  /// 200% text), so the gap is a constant 52 dp of ragged vertical rhythm.
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
  ///
  /// Lebanese pricing is the real case: LBP is zero-decimal and everyday
  /// amounts run to seven digits, so `NumberFormat.simpleCurrency` produces
  /// "L£2,750,000" — 100.8 dp against roughly 50 for "$12.50". Beside it sits a
  /// multi-day ETA, which is the widest the ETA slot ever gets. The row gives
  /// the price an [Expanded] and the ETA a bare `Text` with no [Flexible], so
  /// the ETA takes its intrinsic width FIRST and the price ellipsizes into what
  /// is left.
  ///
  /// All widths below are measured off the render tree through the REAL Inter
  /// and Noto Arabic faces, on the 320 pt frame the preview pins. At 1x there
  /// is nothing to see — the price wants 100.8 dp and is given 219.4 — which is
  /// exactly why the state exists: it only breaks at 200% text, where it wants
  /// 199.9 dp of the 166.8 it gets in EN and 208.3 of 159.3 in AR, and
  /// ellipsizes in both.
  ///
  /// The badge does NOT break with it. "Request declined" measures 208.7 dp at
  /// 200% inside a pill that allows 272, so the `maxLines: 1`-with-no-`overflow`
  /// on `_StatusBadge` is a latent hazard here rather than a live one. The lost
  /// row is in the cast for the badge's COLOURS and for the row-height contrast
  /// (89 dp terminal against 141 dp open, measured at 390/1x).
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
  ///
  /// The screen renders `ListView.builder` and nothing else — no count, no
  /// section header, no sticky summary, no bottom action — so this is what a
  /// busy jeeber's pending list actually looks like: an unlabelled column of
  /// prices whose length is only discoverable by scrolling.
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
