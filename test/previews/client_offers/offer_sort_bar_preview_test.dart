// Render tests for the OfferSortBar previews.

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
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, offerSortBarRatingSelected);

      // 63_W1_TEST_PLAN §2.8 spells these two ids exactly, and the widget's
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
      expect(price.flagsCollection.isSelected, Tristate.isFalse);
      expect(rating.flagsCollection.isSelected, Tristate.isTrue);

      handle.dispose();
    });
  });

  // NOTE ON THE NUMBERS BELOW. Widget tests lay out with the FlutterTest font,
  group('OfferSortBar preview geometry', () {
    setUpAll(loadInterTestFont);

    Rect barRect(WidgetTester tester) =>
        tester.getRect(find.byType(OfferSortBar));

    testWidgets('nothing in the row can give: no flex, no ellipsis', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarProductionSlot);

      // This is the font-independent half of the finding, and the reason the
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
      expect(barRect(tester).width, lessThan(_kProductionWidth));
    });

    testWidgets('at the 200% ceiling the row OVERRUNS the production slot', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarLargeTextInSlot);

      // ~395 dp of content in the same 358 dp slot. AC T-mobile-036 requires
      final Rect bar = barRect(tester);
      expect(bar.width, greaterThan(_kProductionWidth));

      // And it is the TRAILING chip that goes over the edge — the only control
      final Rect rating = tester.getRect(_target('rating'));
      expect(rating.right, greaterThan(bar.left + _kProductionWidth));
    });

    testWidgets('the slot clip keeps the canvas honest and error-free', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerSortBarLargeTextInSlot);

      // The preview deliberately clips rather than overflows, so the state can
      expect(tester.takeException(), isNull);
    });
  });
}
