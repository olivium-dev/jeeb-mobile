import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_card.dart';
import 'package:omds/omds.dart';

import 'support/offers_fixtures.dart';
import 'support/sync_app_localizations.dart';

void main() {
  testWidgets('OfferCard renders the jeeber identity, fee, ETA, vehicle, rating',
      (tester) async {
    final offer = buildOffer(
      id: 'show-me',
      jeeberName: 'Hadi',
      fee: 42.5,
      currency: 'USD',
      etaMinutes: 18,
      vehicle: JeeberVehicle.motorcycle,
      rating: 4.7,
      ratingCount: 132,
    );
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hadi'), findsOneWidget);
    // MoneyFormat renders USD as "$42.50" (currency-unification lane), carried
    // verbatim in the fee pill. Pre-existing stale assertion (was "42.50" + a
    // separate "USD") repaired here so the offers suite stays green.
    expect(find.text(r'$42.50'), findsOneWidget);
    expect(find.text('18 min ETA'), findsOneWidget);
    expect(find.text('Motorcycle'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('(132)'), findsOneWidget);
  });

  testWidgets('OfferCard shows Accepting label and spinner while in-flight',
      (tester) async {
    final offer = buildOffer(id: 'inflight');
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(
          offer: offer,
          index: 0,
          isAccepting: true,
          onAccept: () {},
          onTapName: () {},
        ),
      ),
    );
    // Indefinite spinner — pump once and assert, then settle nothing.
    await tester.pump();

    expect(find.text('Accepting…'), findsOneWidget);
    // OfferCard uses `OmdsButtonLoading` as the in-flight icon (OMDS sweep
    // replaced the raw `CircularProgressIndicator`). `OmdsButtonLoading`
    // still wraps a `CircularProgressIndicator` internally, but assert on
    // the OMDS type so the test fails loudly if the design system swaps
    // implementations.
    expect(find.byType(OmdsButtonLoading), findsOneWidget);
  });

  testWidgets('OfferCard accept tap fires onAccept', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapForTest(OfferCard(
        offer: buildOffer(id: 'tap-me'),
        index: 0,
        onAccept: () => taps++,
        onTapName: () {},
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('offer-card-accept-tap-me')));
    expect(taps, 1);
  });

  testWidgets('OfferCard name tap fires onTapName (→ jeeber-profile-reviews)',
      (tester) async {
    var nameTaps = 0;
    await tester.pumpWidget(
      wrapForTest(OfferCard(
        offer: buildOffer(id: 'name-me', jeeberName: 'Karim'),
        index: 0,
        onAccept: () {},
        onTapName: () => nameTaps++,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('offer-card-name-Karim')));
    expect(nameTaps, 1);
  });

  testWidgets('OfferCard renders the cash-on-delivery line (D11)',
      (tester) async {
    final offer = buildOffer(id: 'cod', fee: 6, currency: 'USD');
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('6.00'), findsWidgets);
  });

  testWidgets(
      'OfferCard renders the note line + offer_card_<index>_note node when '
      'offer.note is present (Lane B)', (tester) async {
    final offer = buildOffer(id: 'noted', note: 'On my way, picking up now');
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On my way, picking up now'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'offer_card_0_note',
      ),
      findsWidgets,
    );
  });

  testWidgets(
      'OfferCard hides the note line + node when offer.note is null (Lane B)',
      (tester) async {
    final offer = buildOffer(id: 'no-note');
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'offer_card_0_note',
      ),
      findsNothing,
    );
  });

  testWidgets('OfferCard hides the note line for a whitespace-only note (trim)',
      (tester) async {
    final offer = buildOffer(id: 'blank-note', note: '   ');
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'offer_card_0_note',
      ),
      findsNothing,
    );
  });

  testWidgets('OfferCard renders Arabic copy under the AR locale',
      (tester) async {
    final offer = buildOffer(
      jeeberName: 'سامي',
      vehicle: JeeberVehicle.bicycle,
      etaMinutes: 9,
    );
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قبول'), findsOneWidget);
    expect(find.text('دراجة هوائية'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // W6 "People, not UUIDs" (sprint-009 SW-08): identity + honest ratings.
  // ---------------------------------------------------------------------------

  testWidgets(
      'OfferCard suppresses a raw UUID jeeberName → "New Jeeber", and the '
      'avatar initial is derived from the resolved name, never a UUID char '
      '(SW-08)', (tester) async {
    final offer = buildOffer(
      id: 'uuid-name',
      jeeberName: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
      rating: 4.8,
      ratingCount: 12,
    );
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // The honest generic replaces the identifier at the accept-ONE moment.
    expect(find.text('New Jeeber'), findsOneWidget);
    // The raw UUID never renders anywhere on the card.
    expect(find.textContaining('9acb579d'), findsNothing);
    // Avatar fallback initial comes from the RESOLVED name ("N"), not '9'.
    expect(
      find.byWidgetPredicate(
        (w) => w is OmdsProfileAvatar && w.initial == 'N',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is OmdsProfileAvatar && w.initial == '9',
      ),
      findsNothing,
    );
  });

  testWidgets(
      'OfferCard suppresses a synthetic jeeb-<hash> handle → "New Jeeber" '
      '(SW-08)', (tester) async {
    final offer = buildOffer(
      id: 'handle-name',
      jeeberName: 'jeeb-e1a35ea8a520',
      ratingCount: 5,
    );
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Jeeber'), findsOneWidget);
    expect(find.textContaining('jeeb-'), findsNothing);
  });

  testWidgets(
      'OfferCard renders "No ratings yet" instead of stars + a fabricated '
      '"4.5 (0)" when ratingCount == 0 (SW-08)', (tester) async {
    final offer = buildOffer(
      id: 'new-jeeber',
      jeeberName: 'Karim',
      rating: 0.0,
      ratingCount: 0,
    );
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // The honest zero-rating line + its assertable node.
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.bySemanticsIdentifier('offer_card_no_ratings'), findsOneWidget);
    // The star display is NOT mounted for a zero-count Jeeber.
    expect(find.byType(OmdsStarRatingDisplay), findsNothing);
    // No fabricated numeric score or "(0)" review count leaks.
    expect(find.text('(0)'), findsNothing);
    expect(find.text('0.0'), findsNothing);
    expect(find.text('4.5'), findsNothing);
    // A real name still shows even when the rating is absent.
    expect(find.text('Karim'), findsOneWidget);
  });

  testWidgets(
      'OfferCard shows the real star display + count when ratingCount > 0 '
      '(SW-08)', (tester) async {
    final offer = buildOffer(id: 'rated', rating: 4.8, ratingCount: 37);
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OmdsStarRatingDisplay), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('(37)'), findsOneWidget);
    expect(find.text('No ratings yet'), findsNothing);
    expect(find.bySemanticsIdentifier('offer_card_no_ratings'), findsNothing);
  });

  testWidgets(
      'OfferCard renders Arabic identity fallbacks (جِيبر جديد / لا تقييمات '
      'بعد) under the AR locale (SW-08)', (tester) async {
    final offer = buildOffer(
      id: 'ar-fallback',
      jeeberName: 'jeeb-e1a35ea8a520', // synthetic handle → suppressed
      rating: 0.0,
      ratingCount: 0,
    );
    await tester.pumpWidget(
      wrapForTest(
        OfferCard(offer: offer, index: 0, onAccept: () {}, onTapName: () {}),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('جِيبر جديد'), findsOneWidget);
    expect(find.text('لا تقييمات بعد'), findsOneWidget);
    expect(find.textContaining('jeeb-'), findsNothing);
  });
}
