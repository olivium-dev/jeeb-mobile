// Render tests for the DeliveryReviewsList previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// `expectedText` can tell these six states apart on copy alone — each pins a
// string only its own state can render. The `preview specifics` group then pins
// what copy cannot: which branch of the widget is live (list vs empty state),
// that the anonymous card really discards its avatar URL, and the two header
// defects the 200% renderings expose.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_reviews_list.dart';
import 'package:jeeb_mobile/previews/delivery_man_profile/delivery_reviews_list_preview.dart';

import '../preview_test_harness.dart';

const Key _listKey = Key('delivery-man-profile-reviews-list');
const Key _emptyKey = Key('delivery-man-profile-reviews-empty');

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryReviewsList',
    const <String, Widget Function()>{
      'Two reviews': deliveryReviewsListTwoReviews,
      'Empty': deliveryReviewsListEmpty,
      'Long body': deliveryReviewsListLongBody,
      'Anonymous reviewer': deliveryReviewsListAnonymous,
      'Stars only': deliveryReviewsListStarsOnly,
      'Year-old review': deliveryReviewsListYearOld,
    },
    expectedText: const <String, String>{
      // One string per state that no other state can render.
      'Two reviews': 'Great delivery, fast and friendly.',
      'Empty': 'No reviews yet',
      'Long body': 'Maroun',
      'Anonymous reviewer': 'Jeeb customer',
      'Stars only': 'Rania',
      'Year-old review': '365 days ago',
    },
  );

  group('DeliveryReviewsList preview specifics', () {
    testWidgets('the previews really are 390 pt wide under test', (
      WidgetTester tester,
    ) async {
      // The render harness pumps an 800 pt surface. If the width were left to
      // the canvas `size`, every state would lay out at 800 pt here — wide
      // enough to hide the header overflow pinned at the bottom of this file.
      await pumpPreview(tester, deliveryReviewsListTwoReviews);
      expect(tester.getSize(find.byType(DeliveryReviewsList)).width, 390.0);

      await pumpPreview(tester, deliveryReviewsListEmpty);
      expect(tester.getSize(find.byType(DeliveryReviewsList)).width, 390.0);
    });

    testWidgets('the loaded state renders the list, not the empty state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListTwoReviews);

      expect(find.byKey(_listKey), findsOneWidget);
      expect(find.byKey(_emptyKey), findsNothing);
      expect(find.byType(DeliveryReviewCard), findsNWidgets(2));
    });

    testWidgets('the empty state replaces the list entirely', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListEmpty);

      expect(find.byKey(_emptyKey), findsOneWidget);
      expect(find.byKey(_listKey), findsNothing);
      expect(find.byType(DeliveryReviewCard), findsNothing);
      expect(
        find.text('Reviews from clients will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('D58: every card attributes by FIRST name only', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListTwoReviews);

      expect(find.text('Karl'), findsOneWidget);
      expect(find.text('Nour'), findsOneWidget);
      expect(find.text('Karl Assaf'), findsNothing);
      expect(find.textContaining('Haddad'), findsNothing);
    });

    testWidgets('D57: no Helpful/Reply controls survive on the cards', (
      WidgetTester tester,
    ) async {
      // The fixtures carry `helpfulCount: 24` precisely so a resurrected
      // control would be visible here rather than silently reappearing.
      await pumpPreview(tester, deliveryReviewsListTwoReviews);

      expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(find.text('Helpful (24)'), findsNothing);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('the anonymous card discards the avatar URL (no network)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListAnonymous);

      expect(find.text('Jeeb customer'), findsOneWidget);
      expect(find.text('?'), findsNothing);
      // The URL in the fixture must never reach an image loader: the avatar
      // falls back to the neutral "J" initial with a null `profilePicUrl`.
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is OmdsProfileAvatar &&
              widget.initial == 'J' &&
              widget.profilePicUrl == null,
        ),
        findsOneWidget,
      );
    });

    testWidgets('the anonymous label is localized, not a "?" in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryReviewsListAnonymous,
        locale: const Locale('ar'),
      );

      expect(find.text('عميل جيب'), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('the stars-only card drops the body and the verified badge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListStarsOnly);

      expect(find.byType(DeliveryReviewCard), findsOneWidget);
      expect(find.text('Rania'), findsOneWidget);
      // `isVerified: false` — the subtitle every other preview shows.
      expect(find.text('Verified Client'), findsNothing);
      // 3.5 stars: three full, one half, one empty.
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_half), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    });

    testWidgets('a long body wraps instead of overflowing at phone width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListLongBody);

      expect(tester.takeException(), isNull);
      // The body is unbounded and the parent scrolls, so the card grows taller
      // than a header-only card rather than clipping its text.
      final double tall = tester
          .getSize(find.byType(DeliveryReviewCard))
          .height;

      await pumpPreview(tester, deliveryReviewsListStarsOnly);
      final double short = tester
          .getSize(find.byType(DeliveryReviewCard))
          .height;

      expect(tall, greaterThan(short));
    });

    testWidgets('the year-old card is clean at 1x — the defect is text scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListYearOld);

      expect(tester.takeException(), isNull);
      expect(find.text('Abdulrahman'), findsOneWidget);
      expect(
        tester.getSize(find.text('Abdulrahman')).width,
        greaterThan(0),
        reason: 'The control for the pinned defect below.',
      );
    });

    // DOCUMENTED DEFECT, not desired behaviour. The card header is
    // `Row(avatar, gap, Expanded(name/badge/stars), Text(daysAgo))` and the
    // timestamp has no Flexible around it, so it takes its natural width and
    // the Expanded column absorbs the whole deficit. At the 200% accessibility
    // ceiling the reviewer's name is allotted ZERO width and the row overflows
    // its trailing edge — the review is attributed to nobody.
    //
    // Pinned so the defect cannot widen silently; DELETE this test when the
    // timestamp learns to yield (it will start failing, which is the point).
    testWidgets('DEFECT: at 200% text the reviewer name is squeezed to zero', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, deliveryReviewsListYearOld);

      expect(
        tester.getSize(find.text('Abdulrahman')).width,
        0.0,
        reason:
            'The name column is Expanded and yields all of its width to '
            'the unconstrained timestamp.',
      );
      expect(
        tester.takeException().toString(),
        contains('overflowed'),
        reason:
            'If this now passes cleanly the header was fixed — delete this '
            'test and the defect notes in the preview.',
      );
    });

    // DOCUMENTED DEFECT. `_ReviewStars` builds `Icon(..., size: Sizes.small)`
    // with no `applyTextScaling`, so the score a review card exists to convey
    // is the one element that ignores the user's text-size setting.
    testWidgets('DEFECT: the stars do not scale with text', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsListYearOld);
      final double star1x = tester.getSize(find.byIcon(Icons.star).first).width;
      final double stamp1x = tester.getSize(find.text('365 days ago')).width;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, deliveryReviewsListYearOld);
      tester.takeException(); // The header overflow pinned above.

      final double star2x = tester.getSize(find.byIcon(Icons.star).first).width;
      final double stamp2x = tester.getSize(find.text('365 days ago')).width;

      expect(
        stamp2x,
        greaterThan(stamp1x * 1.9),
        reason: 'The surrounding text really did scale.',
      );
      expect(
        star2x,
        star1x,
        reason:
            'If this now fails the stars learned to scale — delete this '
            'test and the defect notes in the preview.',
      );
    });
  });
}
