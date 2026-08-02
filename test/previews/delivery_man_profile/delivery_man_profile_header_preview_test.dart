// Render tests for the DeliveryManProfileHeader previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_man_profile_header.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryManProfileHeader',
    const <String, Widget Function()>{
      'Populated (shipped fixture)': deliveryManProfileHeaderPopulated,
      'Cold start · score hidden (D59)': deliveryManProfileHeaderColdStart,
      'From offer card · no location (F9)': deliveryManProfileHeaderNoLocation,
      'Unavailable + unverified': deliveryManProfileHeaderUnavailable,
      'Arabic name, Latin location': deliveryManProfileHeaderArabicName,
      'Longest plausible content': deliveryManProfileHeaderLongest,
    },
    // One string per state that ONLY that state can produce. The header renders
    expectedText: const <String, String>{
      // The score, not the name: the only string that proves the non-cold-start
      'Populated (shipped fixture)': '4.3 . 113 Reviews',
      // The cold-start replacement copy — a count with no score beside it.
      'Cold start · score hidden (D59)': '2 Reviews',
      // Bare availability with no separator and no location: the F9 shape.
      'From offer card · no location (F9)': 'Available',
      'Unavailable + unverified': 'Riyadh . Unavailable',
      'Arabic name, Latin location': 'كمال حاج الطرابلسي',
      'Longest plausible content': '5.0 . 1284 Reviews',
    },
  );

  group('DeliveryManProfileHeader preview specifics', () {
    testWidgets('D59: cold start hides the score, keeps the count', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileHeaderColdStart);

      // Rana Ahmad is a perfect 5.0 over two reviews. Under the D59 threshold
      expect(find.text('2 Reviews'), findsOneWidget);
      expect(find.textContaining('5.0'), findsNothing);
      expect(find.byIcon(Icons.reviews_outlined), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('D59: `profile_score` exists only when the score shows', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, deliveryManProfileHeaderColdStart);
      // The identifier QA asserts on: absent during cold start, so its absence
      expect(find.bySemanticsIdentifier('profile_score'), findsNothing);
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_rating_summary'),
        findsOneWidget,
      );

      await pumpPreview(tester, deliveryManProfileHeaderPopulated);
      expect(find.bySemanticsIdentifier('profile_score'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('F9: an empty location shows availability with no separator', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileHeaderNoLocation);

      // The offer card is the only route into this screen and it always passes
      expect(find.text('Available'), findsOneWidget);
      expect(find.textContaining('· Available'), findsNothing);
      expect(find.textContaining('. Available'), findsNothing);
    });

    testWidgets('the verified badge tracks isVerified, not the review count', (
      WidgetTester tester,
    ) async {
      // TRIPWIRE, not an endorsement. `DeliveryManProfileViewData.isVerified`
      await pumpPreview(tester, deliveryManProfileHeaderNoLocation);
      expect(find.text('0 Reviews'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      // And the negative branch really does drop the glyph.
      await pumpPreview(tester, deliveryManProfileHeaderUnavailable);
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets('a long name wraps instead of ellipsizing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileHeaderLongest);

      // `_NameText` passes no maxLines/overflow, so the full string is laid out
      final RenderParagraph name = tester.renderObject<RenderParagraph>(
        find.text('Abdulrahman Al-Muhandis Al-Trabulsi'),
      );
      expect(name.maxLines, isNull);
      expect(name.overflow, TextOverflow.clip);
      // It fills the 222 dp the verified name column allows and spills onto a
      expect(name.size.width, 222);
      expect(name.size.height, greaterThan(32));
    });

    testWidgets('a long location truncates the availability away at 1x', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileHeaderLongest);

      // `DeliveryManMetaRow._MetaText` sets `overflow: ellipsis` with
      final RenderParagraph location = tester.renderObject<RenderParagraph>(
        find.text('Beirut, Mount Lebanon Governorate . Available'),
      );
      expect(location.didExceedMaxLines, isTrue);
      expect(location.maxLines, isNull);
      expect(location.overflow, TextOverflow.ellipsis);
      // The full 226 dp the meta row leaves after the 16 dp glyph and its gap.
      expect(location.size.width, 226);
    });

    testWidgets('a 4.96 rating is presented as a perfect 5.0', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileHeaderLongest);

      // `rating.toStringAsFixed(1)` rounds UP — the one direction a trust
      expect(find.text('5.0 . 1284 Reviews'), findsOneWidget);
      expect(find.textContaining('4.9'), findsNothing);
    });

    testWidgets('the Arabic name resolves its own direction (UAX #9)', (
      WidgetTester tester,
    ) async {
      // Pumped in the ENGLISH locale on purpose: `AutoDirectionText` picks the
      await pumpPreview(tester, deliveryManProfileHeaderArabicName);

      final RenderParagraph name = tester.renderObject<RenderParagraph>(
        find.text('كمال حاج الطرابلسي'),
      );
      expect(name.textDirection, TextDirection.rtl);

      final RenderParagraph location = tester.renderObject<RenderParagraph>(
        find.text('Lebanon . Available'),
      );
      expect(location.textDirection, TextDirection.ltr);
    });
  });
}
