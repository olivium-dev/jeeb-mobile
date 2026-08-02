// Render tests for the OfferSortBar previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// Every state pins a DISTINCT string, and that is not a formality here: the bar
// renders the same three words whichever chip is selected, so a suite that only
// asked "did something render?" would pass on five copies of the default state.
//
// The suite also needs a second kind of test the text checks cannot give. What
// a reviewer judges in the last two previews is whether the row still fits the
// slot the offers list hands it — a measurement, not a pixel — so the geometry
// group below measures the same rectangles the canvas draws.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_sort_bar.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// The width the offers ListView hands the bar on a 390 dp phone:
/// 390 − 2 × Spacing.medium (`client_offers_screen.dart:230`). A literal, so
/// the geometry group asserts the number the preview claims rather than
/// recomputing it from the same tokens the preview used.
const double _kProductionWidth = 358;

/// The MinTapTarget wrapping each visible chip.
Finder _target(String sort) => find.byKey(Key('offer-sort-$sort'));

/// Whether the capsule under [sort] is painting itself as the live selection.
bool _isSelected(WidgetTester tester, String sort) => tester
    .widget<OmdsChip>(
      find.descendant(of: _target(sort), matching: find.byType(OmdsChip)),
    )
    .isSelected;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OfferSortBar',
    const <String, Widget Function()>{
      'Price selected · default': offerSortBarPriceSelected,
      'Rating selected': offerSortBarRatingSelected,
      'Live toggle': offerSortBarLiveToggle,
      'Production slot · 358 dp': offerSortBarProductionSlot,
      'Production slot · 200% text': offerSortBarLargeTextInSlot,
    },
    expectedText: const <String, String>{
      'Price selected · default': 'Price selected · default',
      'Rating selected': 'Rating selected',
      // The live state pins its readout rather than its caption: the readout
      // reports the mode the bar is actually in, which the caption cannot.
      'Live toggle': 'mode: byPrice',
      'Production slot · 358 dp': 'Production slot · 358 dp',
      'Production slot · 200% text': 'Production slot · 200% text',
    },
  );

  group('OfferSortBar preview states', () {
    testWidgets('the two static states select OPPOSITE chips', (
      WidgetTester tester,
    ) async {
      // The whole visual difference between these two previews is which capsule
      // is filled. If this ever reads the same both ways, the canvas is showing
      // one state twice and the text checks above cannot tell.
      await pumpPreview(tester, offerSortBarPriceSelected);
      expect(_isSelected(tester, 'price'), isTrue);
      expect(_isSelected(tester, 'rating'), isFalse);

      await pumpPreview(tester, offerSortBarRatingSelected);
      expect(_isSelected(tester, 'price'), isFalse);
      expect(_isSelected(tester, 'rating'), isTrue);
    });

    testWidgets('the bar renders the real ARB copy in both locales', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarPriceSelected);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Lowest price'), findsOneWidget);
      expect(find.text('Top rated'), findsOneWidget);

      // The AR rendering of the matrix is only worth something if the bar's own
      // copy actually switches locale — the captions are preview chrome and stay
      // English by design, so pin the Arabic here.
      await pumpPreview(
        tester,
        offerSortBarPriceSelected,
        locale: const Locale('ar'),
      );
      expect(find.text('ترتيب'), findsOneWidget);
      expect(find.text('الأقل سعرًا'), findsOneWidget);
      expect(find.text('الأعلى تقييمًا'), findsOneWidget);
    });

    testWidgets('a tap on the capsule reaches onChanged, both ways', (
      WidgetTester tester,
    ) async {
      // Each chip sits under Semantics → ExcludeSemantics → MinTapTarget, and
      // MinTapTarget's IgnorePointer deliberately kills the chip's own onTap.
      // So "does a tap on the visible capsule change the sort?" is a real
      // question with a real wrong answer, and this is the preview that shows
      // it.
      await pumpPreview(tester, offerSortBarLiveToggle);
      expect(find.text('mode: byPrice'), findsOneWidget);

      await tester.tap(_target('rating'));
      await tester.pumpAndSettle();
      expect(find.text('mode: byRating'), findsOneWidget);
      expect(_isSelected(tester, 'rating'), isTrue);

      await tester.tap(_target('price'));
      await tester.pumpAndSettle();
      expect(find.text('mode: byPrice'), findsOneWidget);
      expect(_isSelected(tester, 'price'), isTrue);
    });

    testWidgets('both chips keep the AC ids, the button role and selection', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      // verification runs BEFORE tearDowns and fails on a live handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, offerSortBarRatingSelected);

      // 63_W1_TEST_PLAN §2.8 spells these two ids exactly, and the widget's
      // class doc calls them EXACT — they are what the e2e suite drives the
      // sort with.
      final SemanticsData price = tester
          .getSemantics(find.bySemanticsIdentifier('offer_review_sort_price'))
          .getSemanticsData();
      final SemanticsData rating = tester
          .getSemantics(find.bySemanticsIdentifier('offer_review_sort_rating'))
          .getSemanticsData();

      expect(price.label, 'Lowest price');
      expect(rating.label, 'Top rated');
      expect(price.flagsCollection.isButton, isTrue);
      expect(rating.flagsCollection.isButton, isTrue);

      // Fill is the only visual channel carrying the selection, so `selected`
      // is the whole of what a screen-reader user gets. `isSelected` is a
      // tristate, and `Tristate` is only reachable from dart:ui.
      expect(price.flagsCollection.isSelected, Tristate.isFalse);
      expect(rating.flagsCollection.isSelected, Tristate.isTrue);

      handle.dispose();
    });
  });

  // NOTE ON THE NUMBERS BELOW. Widget tests lay out with the FlutterTest font,
  // whose every glyph is one em wide — far wider than the shipping Inter face
  // (it measures this row at 389 dp where Inter measures 238). Absolute widths
  // taken under it are worthless for a layout claim, so this group loads the
  // real bundled Inter first, exactly as the golden suites do. The readings
  // that follow are device-accurate.
  group('OfferSortBar preview geometry', () {
    setUpAll(loadInterTestFont);

    Rect barRect(WidgetTester tester) =>
        tester.getRect(find.byType(OfferSortBar));

    testWidgets('nothing in the row can give: no flex, no ellipsis', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarProductionSlot);

      // This is the font-independent half of the finding, and the reason the
      // width below is not a near-miss but a certainty: the label and both
      // chips are non-flexible children of a plain Row, and OmdsChip wraps a
      // bare Text with no maxLines and no overflow policy. Nothing in the chain
      // can shrink, wrap, ellipsize or scroll — so the row's width is its
      // content's width, whatever the slot says.
      //
      // If this test is what turned red, read it as good news and act on it:
      // the row gained some give, so the `Production slot · 200% text` preview
      // is describing a defect that no longer exists and should be re-measured
      // or retired — and `_Slot`'s OverflowBox will need revisiting, since an
      // Expanded child cannot lay out under its unbounded width.
      const String fixedReason =
          'OfferSortBar gained a flex/ellipsis path — re-measure the 200% '
          'preview and update its doc before deleting this expectation.';

      final Finder bar = find.byType(OfferSortBar);
      expect(
        find.descendant(of: bar, matching: find.byType(Flexible)),
        findsNothing,
        reason: fixedReason,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(Wrap)),
        findsNothing,
        reason: fixedReason,
      );
      for (final Text text in tester.widgetList<Text>(
        find.descendant(of: bar, matching: find.byType(Text)),
      )) {
        expect(text.maxLines, isNull, reason: fixedReason);
        expect(text.overflow, isNull, reason: fixedReason);
      }
    });

    testWidgets('at default text the row clears the production slot', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarProductionSlot);

      // ~238 dp of content in a 358 dp slot. This is the headroom reading, and
      // it is why nobody has ever reported this row: at 1× it looks fine with
      // 120 dp to spare.
      expect(barRect(tester).width, lessThan(_kProductionWidth));
    });

    testWidgets('at the 200% ceiling the row OVERRUNS the production slot', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarLargeTextInSlot);

      // ~395 dp of content in the same 358 dp slot. AC T-mobile-036 requires
      // 200% without overflow and A11y.maxTextScaleFactor clamps the OS slider
      // to exactly 2.0, so this is not an extreme — it is the ceiling the app
      // promises to survive, on a 390 dp phone. On the 360 dp S22 the slot is
      // 328 dp and the overrun is worse.
      final Rect bar = barRect(tester);
      expect(bar.width, greaterThan(_kProductionWidth));

      // And it is the TRAILING chip that goes over the edge — the only control
      // that reaches the rating sort. In the app (no clip, no OverflowBox) this
      // is where the RenderFlex overflow stripe gets painted.
      final Rect rating = tester.getRect(_target('rating'));
      expect(rating.right, greaterThan(bar.left + _kProductionWidth));
    });

    testWidgets('the slot clip keeps the canvas honest and error-free', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarLargeTextInSlot);

      // The preview deliberately clips rather than overflows, so the state can
      // be reviewed beside the others instead of throwing; the width assertion
      // above is the actual evidence. If this ever starts throwing, the clip
      // was removed and the shared render suite fails with it.
      expect(tester.takeException(), isNull);
    });
  });
}
