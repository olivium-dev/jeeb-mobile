import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_window_timer.dart';

import 'support/sync_app_localizations.dart';

void main() {
  testWidgets('OfferWindowTimer renders m:ss countdown for normal remaining',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const OfferWindowTimer(
          remaining: Duration(minutes: 2, seconds: 5),
          expired: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Window: 2:05 left'), findsOneWidget);
  });

  testWidgets('OfferWindowTimer renders expired copy past the deadline',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const OfferWindowTimer(remaining: Duration.zero, expired: true),
      ),
    );
    await tester.pump();

    expect(find.text('Offer window expired'), findsOneWidget);
  });

  testWidgets('OfferWindowTimer pads single-digit seconds', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const OfferWindowTimer(
          remaining: Duration(minutes: 0, seconds: 4),
          expired: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Window: 0:04 left'), findsOneWidget);
  });
}
