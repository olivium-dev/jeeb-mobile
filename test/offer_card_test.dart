import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_card.dart';

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
      wrapForTest(OfferCard(offer: offer, onAccept: () {})),
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
        OfferCard(offer: offer, isAccepting: true, onAccept: () {}),
      ),
    );
    // Indefinite spinner — pump once and assert, then settle nothing.
    await tester.pump();

    expect(find.text('Accepting…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('OfferCard accept tap fires onAccept', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapForTest(OfferCard(
        offer: buildOffer(id: 'tap-me'),
        onAccept: () => taps++,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('offer-card-accept-tap-me')));
    expect(taps, 1);
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
        OfferCard(offer: offer, onAccept: () {}),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قبول'), findsOneWidget);
    expect(find.text('دراجة هوائية'), findsOneWidget);
  });
}
