/// Widget previews for [OfferCard] — run with `flutter widget-preview start`.
///
/// [OfferCard] is deliberately dumb (40_GUARDRAILS_ARCH §1): it takes an [Offer]
/// plus two booleans from `ClientOffersCubit` and emits two callbacks. There is
/// no cubit, no `sl`, and no repository to fake, so every state below is a pure
/// function of its fixture — these previews are network-free by construction,
/// not merely by the guard in [jeebPreviewHost].
///
/// One rule the fixtures follow that is easy to break: `avatarUrl` stays **null**
/// everywhere. A non-null URL makes `OmdsProfileAvatar` build a `NetworkImage`,
/// which is a real HTTP GET that the guard would happily allow (it only rejects
/// mutating verbs). Null keeps the initial-letter placeholder — which is also
/// what the SW-08 assertions below are about.
///
/// Fixture values reuse `test/offer_card_test.dart` and
/// `test/features/client_offers/offer_card_overflow_test.dart` (Hadi / $42.50 /
/// 18 min / 4.7 (132); the UUID name; the LBP 1,234,567,890.99 ceiling) so the
/// canvas and the widget suite describe the same card.
///
/// ## Read the canvas knowing these three things
///
/// **1. The widget tests never see phone width.** `offer_card_overflow_test.dart`
/// pumps into an 800×600 viewport and asserts only "no exception thrown". No
/// exception is ever thrown here — nothing in this card can overflow, because
/// every text node is `maxLines` + `ellipsis` and both chip rows are `Wrap`s.
/// It degrades by *silently dropping characters*, which a test that watches for
/// `RenderFlex overflow` cannot see and the canvas shows immediately. Measured
/// at 390 pt, the first thing each rendering loses:
///
/// | rendering        | 100%          | 130%                 | 200%                        |
/// |------------------|---------------|----------------------|-----------------------------|
/// | EN, USD fee      | —             | —                    | name ("Nadine Khou…")       |
/// | EN, LBP fee      | —             | **fee pill clipped** | fee pill + name             |
/// | AR, USD fee      | —             | — (360 pt: ETA chip) | **ETA chip** + name         |
/// | AR, LBP fee      | —             | **fee pill clipped** | fee pill + ETA chip + name  |
///
/// **2. The card fills the preview box vertically.** Its inner `Column` is
/// `mainAxisSize.max` and [jeebPreviewHost] hands the `Scaffold` body a tight
/// height, so the border stretches to whatever `size:` says. In production the
/// card is a `ListView` child (`client_offers_screen.dart`) and shrink-wraps.
/// That is a canvas artifact, not a bug — the `size:` heights below are the
/// measured intrinsic ones so it stays close to the real thing: 292 pt EN /
/// 332 pt AR at 100% (Arabic line height makes every card ~40 pt taller), and
/// ~500 pt at 200%, which no honest box height can contain.
///
/// **3. `isAccepting` is unreachable in the shipped app.** See
/// [offerCardAccepting].
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../features/client_offers/domain/offer.dart';
import '../../features/client_offers/presentation/widgets/offer_card.dart';

/// Phone width; height fits the measured 100%-text card in BOTH locales
/// (EN 292 pt, AR 332 pt). The 200% rendering is ~500 pt and will clip.
const Size _cardBox = Size(390, 340);

/// Anchor timestamp shared with `test/support/offers_fixtures.dart` so a preview
/// and a widget test never disagree about "when" an offer arrived.
final DateTime _submittedAt = DateTime.utc(2026, 5, 17, 12);

/// Builds the card the way `client_offers_screen.dart` builds it — the only
/// production caller — so a preview cannot show a prop combination the app
/// never ships.
///
/// [isAccepting] and [acceptDisabled] are mutually exclusive: the cubit marks
/// the one offer whose accept is in flight, and disables every other card.
Widget _hosted({
  required String id,
  required String jeeberName,
  double fee = 30,
  String currency = 'USD',
  int etaMinutes = 12,
  JeeberVehicle vehicle = JeeberVehicle.scooter,
  double rating = 4.6,
  int ratingCount = 80,
  String? note,
  bool isAccepting = false,
  bool acceptDisabled = false,
}) {
  return OfferCard(
    offer: Offer(
      id: id,
      jeeberId: 'jeeber-$id',
      jeeberName: jeeberName,
      fee: fee,
      currency: currency,
      etaMinutes: etaMinutes,
      vehicle: vehicle,
      rating: rating,
      ratingCount: ratingCount,
      submittedAt: _submittedAt,
      // avatarUrl intentionally omitted — see the library doc comment.
      note: note,
    ),
    index: 0,
    isAccepting: isAccepting,
    acceptDisabled: acceptDisabled,
    onAccept: () {},
    onTapName: () {},
  );
}

/// The reference rendering: a named, rated Jeeber with an armed Accept CTA.
///
/// Every other state is read against this one. Three contracts are visible at
/// once — the name is an underlined tap target (→ JM-067 profile-reviews), the
/// fee is a single `MoneyFormat` token (`$42.50`, never a bare "42.50" beside a
/// separate "USD"), and the "Pay … cash on delivery" line (D11) repeats that
/// same token so the client cannot read this as an in-app charge.
@JeebPreview(group: 'client_offers', name: 'Rated jeeber', size: _cardBox)
Widget offerCardRated() => _hosted(
      id: 'preview-rated',
      jeeberName: 'Hadi',
      fee: 42.5,
      etaMinutes: 18,
      vehicle: JeeberVehicle.motorcycle,
      rating: 4.7,
      ratingCount: 132,
    );

/// A brand-new Jeeber: real name, zero ratings (SW-08).
///
/// `ratingCount == 0` drops `OmdsStarRatingDisplay` entirely in favour of the
/// honest "No ratings yet" line. The regression it guards is the fabricated
/// "4.5 (0)" the star widget draws for an unrated account — five empty stars
/// read as *rated zero*, a different and defamatory claim about a Jeeber who
/// has simply never been rated.
///
/// Check the AR rendering: the fallback must be the translated string
/// ("لا تقييمات بعد"), not English.
///
/// This is also the cheapest place to see the 200% name clip: "Nadine Khoury"
/// is thirteen characters and still ellipsizes at 390 pt.
@JeebPreview(group: 'client_offers', name: 'New jeeber, no ratings', size: _cardBox)
Widget offerCardNoRatings() => _hosted(
      id: 'preview-unrated',
      jeeberName: 'Nadine Khoury',
      fee: 18,
      etaMinutes: 25,
      vehicle: JeeberVehicle.bicycle,
      rating: 0,
      ratingCount: 0,
    );

/// W6 "People, not UUIDs" (sprint-009 SW-08) made visible.
///
/// The offer-list row is NOT enriched with a display name by the gateway (the
/// O-list-enrich gap in `DioOffersRepository`), so `jeeberName` arrives as a raw
/// UUID or a synthetic `jeeb-<hash>` handle far more often than as a person.
/// `displayNameOrNull` suppresses both and the card headlines the localized
/// generic instead.
///
/// Two things to look at, because both have regressed before: the raw
/// identifier must appear NOWHERE on the card, and the avatar initial must be
/// derived from the *resolved* name ("N" for New Jeeber) — taking it from the
/// raw value once put a "9" in the circle beside the words "New Jeeber".
@JeebPreview(group: 'client_offers', name: 'UUID name suppressed', size: _cardBox)
Widget offerCardIdentitySuppressed() => _hosted(
      id: 'preview-uuid-name',
      jeeberName: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
      fee: 24,
      etaMinutes: 15,
      vehicle: JeeberVehicle.car,
      rating: 4.8,
      ratingCount: 12,
    );

/// Accept tapped, `POST …/accept` in flight on THIS offer: "Accepting…" plus an
/// `OmdsButtonLoading` spinner, CTA locked.
///
/// **The shipped app never renders this.** `client_offers_screen.dart` passes
/// `isAccepting: false` unconditionally (B-01: the JM-029 confirm sheet owns the
/// in-flight spinner and the cards behind it merely go inert), so the whole
/// `isAccepting` branch is live API that only `test/offer_card_test.dart`
/// exercises. Keep it previewed rather than deleting it: it is what the card
/// would show the moment anyone wires an inline accept, and this comment is the
/// only place that says it is currently dead.
///
/// It is also the one state whose render test cannot use `pumpAndSettle` — the
/// spinner is an indefinite animation, so the harness's settle would time out.
/// See the dedicated pump-once test in
/// `test/previews/client_offers/offer_card_preview_test.dart`.
@JeebPreview(group: 'client_offers', name: 'Accept in flight', size: _cardBox)
Widget offerCardAccepting() => _hosted(
      id: 'preview-accepting',
      jeeberName: 'Rami Aoun',
      fee: 35,
      etaMinutes: 20,
      vehicle: JeeberVehicle.van,
      rating: 4.9,
      ratingCount: 54,
      isAccepting: true,
    );

/// A rival offer is mid-accept (or the window expired, or the request closed),
/// so this card's CTA is inert.
///
/// Put it beside `Rated jeeber` in the canvas — unlike the chat-bubble offer
/// card, this one tells the truth: `acceptDisabled` reaches
/// `OmdsPrimaryButton.isEnabled`, so the pill drops to the 45%-alpha disabled
/// fill and the semantics node reports `hasEnabledState` *without* `isEnabled`
/// and without a tap action. That is the visible half of the accept-race
/// (409 / 410 `offer-expired`) contract.
///
/// The CTA stays *mounted* rather than being removed: the card must not change
/// height while a rival accept resolves, because a list that reflows under the
/// finger is how a client taps the wrong Jeeber.
@JeebPreview(group: 'client_offers', name: 'Accept locked (rival winning)', size: _cardBox)
Widget offerCardAcceptLocked() => _hosted(
      id: 'preview-locked',
      jeeberName: 'Nour Haddad',
      fee: 41,
      etaMinutes: 35,
      vehicle: JeeberVehicle.walker,
      rating: 4.2,
      ratingCount: 9,
      acceptDisabled: true,
    );

/// The layout ceiling from `offer_card_overflow_test.dart`, plus a note:
/// longest plausible name, a non-USD nine-figure fee, a nine-figure rating
/// count, and a note past its three-line limit, all at once.
///
/// What each element must do under pressure: the name ellipsizes on one line
/// (in AR the ellipsis has to land on the *left*); the rating summary and the
/// fee pill share a `Wrap`, so they split across runs instead of overflowing;
/// the note ellipsizes after three lines. The `LBP …` token is wrapped in a
/// Unicode LTR isolate (JEBV4-98 / F10) so it does not scramble inside the
/// Arabic paragraph — the AR rendering is the only place that is checkable.
///
/// The fee pill is `maxLines: 1`, and this is where that bites: it clips the
/// amount rather than wrapping it, and it does so for realistic LBP prices too,
/// not just this synthetic ceiling (`LBP 1,335,000.00` — a $15 delivery at the
/// 2026 peg — is already clipped at 130% text on a 390 pt phone). The
/// cash-on-delivery line below has no `maxLines` and keeps the full amount, so
/// the card can show a truncated price above an untruncated one.
@JeebPreview(group: 'client_offers', name: 'Long name, note, LBP ceiling', size: Size(390, 430))
Widget offerCardLongContent() => _hosted(
      id: 'preview-long',
      jeeberName: 'Alexander Bartholomew Montgomery the Third',
      fee: 1234567890.99,
      currency: 'LBP',
      etaMinutes: 90,
      vehicle: JeeberVehicle.van,
      rating: 4.9,
      ratingCount: 1234567890,
      note: 'I am two streets away and can take the parcel right now, but the '
          'building has no lift so please meet me at the door on the ground '
          'floor.',
    );
