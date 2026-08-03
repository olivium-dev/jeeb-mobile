import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_meter.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_window_timer.dart';

import 'support/sync_app_localizations.dart';

void main() {
  testWidgets(
    'OfferWindowTimer merges the offer count and the m:ss countdown into one '
    'strip',
    (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const OfferWindowTimer(
            remaining: Duration(minutes: 2, seconds: 5),
            expired: false,
            offerCount: 3,
            progress: 0.65,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('3 offers in · window closes in 2:05'),
        findsOneWidget,
      );
      // The meter renders the fraction it was handed — never a guess.
      expect(
        tester.widget<JeebMeter>(find.byType(JeebMeter)).value,
        0.65,
      );
    },
  );

  testWidgets(
    'OfferWindowTimer renders expired copy past the deadline and drops the '
    'meter',
    (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const OfferWindowTimer(remaining: Duration.zero, expired: true),
        ),
      );
      await tester.pump();

      expect(find.text('Offer window expired'), findsOneWidget);
      expect(find.byType(JeebMeter), findsNothing);
    },
  );

  testWidgets('OfferWindowTimer pads single-digit seconds', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const OfferWindowTimer(
          remaining: Duration(minutes: 0, seconds: 4),
          expired: false,
          offerCount: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 offer in · window closes in 0:04'), findsOneWidget);
  });

  testWidgets(
    'OfferWindowTimer renders a track-only meter when the app has no honest '
    'window total',
    (tester) async {
      await tester.pumpWidget(
        wrapForTest(
          const OfferWindowTimer(
            remaining: Duration(minutes: 4, seconds: 12),
            expired: false,
            offerCount: 2,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('2 offers in · window closes in 4:12'),
        findsOneWidget,
      );
      final meter = tester.widget<JeebMeter>(find.byType(JeebMeter));
      expect(
        meter.value,
        isNull,
        reason: 'no denominator → track only, never a fabricated fraction',
      );
    },
  );
}
