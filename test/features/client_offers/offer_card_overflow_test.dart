import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_card.dart';

import '../../support/offers_fixtures.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  testWidgets('OfferCard header does not overflow at S24 width and 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(411, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final offer = buildOffer(
      id: 'large-text-header',
      jeeberName: 'Alexander Bartholomew Montgomery the Third',
      fee: 1234567890.99,
      currency: 'LBP',
      rating: 4.9,
      ratingCount: 1234567890,
    );

    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: OfferCard(
              offer: offer,
              index: 0,
              onAccept: () {},
              onTapName: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
