// Render tests for the RecentDeliveryCard previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/recent_delivery_card.dart';

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
      expect(find.text('Mini-market run'), findsOneWidget);
    });

    testWidgets('the card renders no recency information at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, recentDeliveryCardTypical);

      // `completedAt` is required by RecentDeliverySummary and used by nothing
      expect(find.textContaining('2026'), findsNothing);
      expect(find.textContaining('May'), findsNothing);
      expect(find.textContaining('ago'), findsNothing);
    });
  });
}
