// Render tests for the DeliveryManProfileScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen is one value rendered three ways — identity header, section
// header, review list — and several of its states differ only in the NUMBERS
// on those lines. A render-only check would therefore pass on a preview wired
// to the wrong fixture, so every state pins the jeeber's name (unique per
// fixture) and the specifics group below pins what the state is FOR: the
// duplicated count line under D59, the empty list under a non-zero count, the
// truncation of the availability word, and both navigation edges.
//
// One preview per test, always. `previewCanvas` produces the same widget types
// for every preview, so pumping a second one into the same tester UPDATES the
// host element rather than replacing it — the `late final` GoRouter survives
// and the second preview would silently show the first one's stack under the
// second one's name.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';

import '../preview_test_harness.dart';

/// The close "X" — the only affordance that leaves this modal screen.
final Finder _close = find.byKey(const Key('delivery-man-profile-close'));

/// "View all", from `_ViewAllButton`.
final Finder _viewAll = find.byKey(const Key('delivery-man-profile-view-all'));

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryManProfileScreen',
    const <String, Widget Function()>{
      'Populated · shipped fixture': deliveryManProfileScreenPopulated,
      'Cold start · score hidden (D59)': deliveryManProfileScreenColdStart,
      'Empty · no reviews yet': deliveryManProfileScreenEmpty,
      'From the offer card · 113 reviews, none shown':
          deliveryManProfileScreenFromOfferCard,
      'First review · "1 Reviews", twice':
          deliveryManProfileScreenFirstReview,
      'Longest plausible content': deliveryManProfileScreenLongest,
      'Compact 320 pt · Arabic name':
          deliveryManProfileScreenCompactArabicName,
    },
    // The jeeber's name, which is unique per fixture and rendered exactly once
    // (`_NameText`). Every other line on this screen — "N Reviews", "No reviews
    // yet", "View all" — is shared by several states, and two of them render it
    // twice.
    expectedText: const <String, String>{
      'Populated · shipped fixture': 'Kamal Hajj',
      'Cold start · score hidden (D59)': 'Rana Ahmad',
      'Empty · no reviews yet': 'New Jeeber',
      'From the offer card · 113 reviews, none shown': 'Maya Rizk',
      'First review · "1 Reviews", twice': 'Nour Haddad',
      'Longest plausible content': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      'Compact 320 pt · Arabic name': 'عبد الرحمن المهندس الطرابلسي',
    },
  );

  group('DeliveryManProfileScreen preview specifics', () {
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of the layout under review
      // applies at that width.
      await pumpPreview(tester, deliveryManProfileScreenPopulated);

      expect(tester.getSize(find.byType(DeliveryManProfileScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenCompactArabicName);

      expect(
        tester.getSize(find.byType(DeliveryManProfileScreen)),
        const Size(320, 568),
      );
    });

    // The state a real tap produces. `ClientOffersScreen._openJeeberProfile`
    // hardcodes `reviews: const []`, so the header's count and the list never
    // agree.
    testWidgets('the offer-card state claims 113 reviews over an empty list, '
        'with nothing to reconcile them', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryManProfileScreenFromOfferCard);

      // Identity header (aggregate) and section header (count) both say 113…
      expect(find.text('4.7 . 113 Reviews'), findsOneWidget);
      expect(find.text('113 Reviews'), findsOneWidget);
      // …over the empty state.
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('Reviews from clients will appear here.'), findsOneWidget);
      // No loading state, no error state, nothing to retry with: the screen is
      // a pure value and has no vocabulary for "the reviews did not load".
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('F9: with no location the availability label stands alone', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenFromOfferCard);

      expect(find.text('Available'), findsOneWidget);
      expect(find.textContaining(' . Available'), findsNothing);
    });

    testWidgets('an unreviewed jeeber and a failed reviews read are the SAME '
        'picture', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryManProfileScreenEmpty);

      expect(find.text('No reviews yet'), findsOneWidget);
      // …and "View all" is still live, pushing a paginated list that has
      // nothing in it either.
      expect(_viewAll, findsOneWidget);
    });

    testWidgets('D59 cold start hides the score and renders the count TWICE', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, deliveryManProfileScreenColdStart);

      // The score is gone — this is how QA asserts D59.
      expect(find.bySemanticsIdentifier('profile_score'), findsNothing);
      expect(find.text('5.0 . 2 Reviews'), findsNothing);
      // The identity header substitutes the count for the hidden score, and
      // the section header below it renders the same string again.
      expect(find.text('2 Reviews'), findsNWidgets(2));
      handle.dispose();
    });

    testWidgets('a jeeber\'s first review reads "1 Reviews" — twice', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenFirstReview);

      // `{count} Reviews` is a literal substitution, not an ICU plural, and
      // D59 cold start renders the same key in the score's place.
      expect(find.text('1 Reviews'), findsNWidgets(2));
      expect(find.text('1 Review'), findsNothing);
    });

    testWidgets('the populated fixture shows 2 cards under a header that says '
        '113, with no "showing 2 of 113"', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, deliveryManProfileScreenPopulated);

      expect(
        find.bySemanticsIdentifier('delivery_man_profile_review_card_0'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_review_card_1'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_review_card_2'),
        findsNothing,
      );
      expect(find.text('113 Reviews'), findsOneWidget);
      handle.dispose();
    });

    // D57 (immutable reviews) and D58 (first-name attribution) are the two
    // rules this screen was re-specified around; both are card-level and both
    // are only visible with real review data on the page.
    testWidgets('D57/D58: no Helpful or Reply, first names only', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenPopulated);

      expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
      expect(find.text('Helpful (24)'), findsNothing);
      expect(find.text('Reply'), findsNothing);
      // Both seed reviews are by "Karl Assaf".
      expect(find.text('Karl'), findsNWidgets(2));
      expect(find.text('Karl Assaf'), findsNothing);
    });

    testWidgets('the anonymous review drops its avatar URL and its name', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenLongest);

      // Privacy guard: a blank reviewer name must attribute to the localized
      // label with a neutral initial, never to a bare "?" and never beside the
      // client's own photo.
      expect(find.text('?'), findsNothing);
      expect(find.text('J'), findsOneWidget);
    });

    // Measured, not eyeballed: `_MetaText` sets `overflow: ellipsis` with
    // `maxLines: null`, which the paragraph builder resolves to single-line
    // truncation — and `Text` cuts the END, which is where the availability
    // state lives.
    testWidgets('the longest location truncates AT 1x, and what is cut is the '
        'availability state', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryManProfileScreenLongest);

      final RenderParagraph location = tester.renderObject<RenderParagraph>(
        find.text('Beirut, Mount Lebanon Governorate . Available'),
      );
      expect(
        location.didExceedMaxLines,
        isTrue,
        reason: 'if this ever passes, the meta row learned to wrap or the '
            'label learned to yield — delete this expectation and the note in '
            'the preview library doc',
      );
    });

    testWidgets('at the 320 pt floor the word being cut is "Unavailable"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenCompactArabicName);

      final RenderParagraph location = tester.renderObject<RenderParagraph>(
        find.text('Beirut, Mount Lebanon Governorate . Unavailable'),
      );
      // Availability is carried by ONE word, joined onto the end of the
      // location in a single string, and `Text` truncates the end.
      expect(location.didExceedMaxLines, isTrue);
    });

    testWidgets('rating 4.96 is presented as a perfect 5.0', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenLongest);

      // `toStringAsFixed(1)` rounds a trust signal UP.
      expect(find.text('5.0 . 1284 Reviews'), findsOneWidget);
    });

    testWidgets('profile_view_all_reviews pushes reviews-list with the '
        'jeeber id', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryManProfileScreenColdStart);

      await tester.tap(_viewAll);
      await tester.pumpAndSettle();

      expect(find.text('reviews-list?jeeberId=jeeber-rana'), findsOneWidget);
    });

    testWidgets('profile_close pops back to the offer list it was pushed from', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenPopulated);

      await tester.tap(_close);
      await tester.pumpAndSettle();

      expect(find.text('offer-review-list'), findsOneWidget);
      expect(find.byType(DeliveryManProfileScreen), findsNothing);
    });

    testWidgets('the only exit is inked with a container role', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManProfileScreenPopulated);

      final IconButton button = tester.widget<IconButton>(_close);
      expect(
        button.color,
        AppTheme.light().colorScheme.secondaryContainer,
        reason: '`_CloseButton` passes `colorScheme.secondaryContainer` — a '
            'fill role — as the icon colour; the contrast test below is what '
            'that costs in dark',
      );
    });

    test('the close X clears the UI-component floor in light and fails it in '
        'dark', () {
      // The X sits on the app bar, whose background is `colorScheme.surface`
      // (`OMDSAppBar` + `AppTheme.appBarTheme`).
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.secondaryContainer, light.surface),
        greaterThanOrEqualTo(3.0),
        reason: 'the light scheme hard-codes that role to the brand navy, so '
            'navy-on-white clears the 3:1 floor by a mile — it must not '
            'regress',
      );

      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        _contrast(dark.secondaryContainer, dark.surface),
        lessThan(3.0),
        reason: 'in dark, `ColorScheme.fromSeed(_jeebNavy, dark)` resolves '
            'that role to a dark container tone on an almost equally dark '
            'surface, so the ONLY way off this modal screen is under the 3:1 '
            'WCAG floor for a UI component. The correct role is `onSurface`, '
            'never a `*Container` one. If this ever passes 3:1 the palette or '
            'the role was fixed — delete this expectation and the note in the '
            'preview library doc',
      );
    });

    // The accessibility ceiling the matrix renders, run in the locale that
    // lengthens the copy, at the width that has least of it to spare.
    testWidgets('the compact Arabic state survives AR at 200% text', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(
        tester,
        deliveryManProfileScreenCompactArabicName,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the longest content survives AR at 200% text', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(
        tester,
        deliveryManProfileScreenLongest,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
