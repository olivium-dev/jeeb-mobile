// Render tests for the RecentDeliveryCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The specifics group pins the three things the card's fixtures are chosen to
// expose: the clip-never-wrap contract on both lines, the empty-string
// destination the Dio parser really produces, and the fact that the CTA label
// is the only localized string on the card.
//
// Note the viewport: these tests pump into the standard 800×600 surface, where
// the text column is ~575 pt and nothing clips. The truncation documented in
// the preview library doc is a 390/360/320 pt finding and is deliberately NOT
// asserted here — asserting it would only pin the test viewport.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/recent_delivery_card.dart';
import 'package:jeeb_mobile/previews/home_client/recent_delivery_card_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RecentDeliveryCard',
    const <String, Widget Function()>{
      'Typical': recentDeliveryCardTypical,
      'Arabic content': recentDeliveryCardArabicContent,
      'Degraded payload': recentDeliveryCardDegradedPayload,
      'Long title + long destination': recentDeliveryCardLongContent,
      'Small phone (320 pt)': recentDeliveryCardSmallPhone,
    },
    expectedText: const <String, String>{
      'Typical': 'Mini-market run',
      // Content, not chrome: this string comes from the gateway, so it renders
      // identically in the EN and AR canvases.
      'Arabic content': 'طلبية سوبرماركت',
      'Degraded payload': 'Delivery #CC42E6',
      'Long title + long destination':
          'Pharmacy pickup for Mrs. Haddad on Rue Sursock and the bakery '
              'next door',
      'Small phone (320 pt)': 'Bakery order',
    },
  );

  group('RecentDeliveryCard preview specifics', () {
    testWidgets('both lines clip — they never wrap', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentDeliveryCardLongContent);

      final Text title = tester.widget<Text>(
        find.textContaining('Pharmacy pickup for Mrs. Haddad'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);

      final Text destination = tester.widget<Text>(
        find.textContaining('near the Sursock Museum'),
      );
      expect(destination.maxLines, 1);
      expect(destination.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      'degraded payload keeps a blank destination line and hides the raw id',
      (WidgetTester tester) async {
        await pumpPreview(tester, recentDeliveryCardDegradedPayload);

        // `_parseRecentDelivery` emits '' for a row with no dropoff address,
        // and the card renders it verbatim: an empty line where the address
        // belongs, with no "unknown destination" copy in its place.
        expect(
          find.descendant(
            of: find.byType(RecentDeliveryCard),
            matching: find.text(''),
          ),
          findsOneWidget,
        );
        // The friendly reference is shown; the opaque UUID never is.
        expect(find.text('Delivery #CC42E6'), findsOneWidget);
        expect(
          find.textContaining('9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6'),
          findsNothing,
        );
      },
    );

    testWidgets('the re-order CTA is keyed by the summary id', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentDeliveryCardTypical);

      expect(find.byKey(const Key('recent-delivery-reorder-rd-2f1c')),
          findsOneWidget);
    });

    testWidgets('the CTA label is localized; the content is not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        recentDeliveryCardTypical,
        locale: const Locale('ar'),
      );

      // Chrome follows the locale…
      expect(find.text('إعادة الطلب'), findsOneWidget);
      expect(find.text('Re-order'), findsNothing);
      // …while the gateway-supplied title/destination stay exactly as stored.
      // This is why 'Arabic content' exists as a separate preview.
      expect(find.text('Mini-market run'), findsOneWidget);
    });

    testWidgets('the card renders no recency information at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentDeliveryCardTypical);

      // `completedAt` is required by RecentDeliverySummary and used by nothing
      // in this widget: two repeats of the same order are indistinguishable on
      // the "order again" surface.
      expect(find.textContaining('2026'), findsNothing);
      expect(find.textContaining('May'), findsNothing);
      expect(find.textContaining('ago'), findsNothing);
    });
  });
}
