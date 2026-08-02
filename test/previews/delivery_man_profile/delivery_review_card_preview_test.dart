// Render tests for the DeliveryReviewCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. The `expectedText` map is the load-bearing
// half: it proves each preview renders ITS OWN state, which is what separates a
// real regression from six cards that all happen to draw.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart';
import 'package:jeeb_mobile/previews/delivery_man_profile/delivery_review_card_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryReviewCard',
    const <String, Widget Function()>{
      'Verified, 4 stars': deliveryReviewCardVerified,
      'Anonymous reviewer': deliveryReviewCardAnonymous,
      'Rating only, no body': deliveryReviewCardNoBody,
      'Half star': deliveryReviewCardHalfStar,
      'Unverified reviewer': deliveryReviewCardUnverified,
      'Long name and body': deliveryReviewCardLongContent,
    },
    expectedText: const <String, String>{
      'Verified, 4 stars': 'Great delivery, fast and friendly.',
      'Anonymous reviewer': 'Jeeb customer',
      'Rating only, no body': 'Nadia',
      'Half star': 'Arrived on time, but the bag was a little squashed.',
      'Unverified reviewer': 'Took a while to find the building.',
      'Long name and body': 'Abdulrahman',
    },
  );

  group('DeliveryReviewCard preview specifics', () {
    testWidgets('attributes the reviewer by FIRST name only (D58)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewCardVerified);

      expect(find.text('Karl'), findsOneWidget);
      expect(find.textContaining('Assaf'), findsNothing);
    });

    testWidgets('blank reviewer shows the localized label, never "?"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewCardAnonymous);

      expect(find.text('Jeeb customer'), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('blank reviewer is localized in Arabic too', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryReviewCardAnonymous,
        locale: const Locale('ar'),
      );

      expect(find.text('عميل جيب'), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('an empty body collapses the card, it does not leave a gap', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewCardNoBody);
      final double withoutBody =
          tester.getSize(find.byType(DeliveryReviewCard)).height;

      await pumpPreview(tester, deliveryReviewCardVerified);
      final double withBody =
          tester.getSize(find.byType(DeliveryReviewCard)).height;

      expect(withoutBody, lessThan(withBody));
    });

    testWidgets('a half star reads as "4.5 of 5 stars" to a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, deliveryReviewCardHalfStar);

      expect(find.bySemanticsLabel('4.5 of 5 stars'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the verified badge is conditional, not decoration', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewCardVerified);
      expect(find.text('Verified Client'), findsOneWidget);

      await pumpPreview(tester, deliveryReviewCardUnverified);
      expect(find.text('Verified Client'), findsNothing);
    });

    testWidgets('each preview carries its own Semantics id', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, deliveryReviewCardVerified);
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_review_card_0'),
        findsOneWidget,
      );

      await pumpPreview(tester, deliveryReviewCardLongContent);
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_review_card_5'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
