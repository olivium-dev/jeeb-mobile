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
    expect(find.text('42.50'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
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
}
