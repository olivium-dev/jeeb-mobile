// Render tests for the DeliveryManMetaRow previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_man_meta_row.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Rating summary': deliveryManMetaRowRatingSummary,
  'Cold start (D59)': deliveryManMetaRowColdStart,
  'No reviews yet': deliveryManMetaRowNoReviews,
  'Location + availability': deliveryManMetaRowLocationAvailability,
  'Availability only (F9)': deliveryManMetaRowAvailabilityOnly,
  'Longest location (small phone)': deliveryManMetaRowLongestLocation,
};

const Map<String, List<String>> _labels = <String, List<String>>{
  'Rating summary': <String>['4.3 . 113 Reviews', '4.3 . 113 تقييم'],
  'Cold start (D59)': <String>['3 Reviews', '3 تقييم'],
  'No reviews yet': <String>['0 Reviews', '0 تقييم'],
  'Location + availability': <String>['Lebanon . Available', 'Lebanon . متاح'],
  'Availability only (F9)': <String>['Unavailable', 'غير متاح'],
  'Longest location (small phone)': <String>[
    'Bourj Hammoud, Mount Lebanon . Unavailable',
    'Bourj Hammoud, Mount Lebanon . غير متاح',
  ],
};

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

/// Whether [text] was ellipsized rather than shown in full.
bool _truncated(WidgetTester tester, String text) =>
    _paragraph(tester, text).didExceedMaxLines;

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() async {
    loadPreviewArbs();
    // Geometry, not glyphs, is what the long states are for — the widths are
    await loadInterTestFont();
  });

  testPreviewsRender(
    'DeliveryManMetaRow',
    _previews,
    expectedText: const <String, String>{
      'Rating summary': '4.3 . 113 Reviews',
      'Cold start (D59)': '3 Reviews',
      'No reviews yet': '0 Reviews',
      'Location + availability': 'Lebanon . Available',
      'Availability only (F9)': 'Unavailable',
      'Longest location (small phone)':
          'Bourj Hammoud, Mount Lebanon . Unavailable',
    },
  );

  group('DeliveryManMetaRow preview specifics', () {
    testWidgets('the F9 state shows availability with NO leading separator', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManMetaRowAvailabilityOnly);

      expect(find.text('Unavailable'), findsOneWidget);
      // Neither the "· Unavailable" (middle-dot) nor the " . Unavailable" (ARB
      expect(find.textContaining('·'), findsNothing);
      expect(find.textContaining('. Unavailable'), findsNothing);
    });

    testWidgets('each row keeps its own semantics identifier', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      // The warm branch owns `profile_score`; the D59 cold-start branch must
      await pumpPreview(tester, deliveryManMetaRowRatingSummary);
      expect(find.bySemanticsIdentifier('profile_score'), findsOneWidget);

      await pumpPreview(tester, deliveryManMetaRowColdStart);
      expect(find.bySemanticsIdentifier('profile_score'), findsNothing);
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_rating_summary'),
        findsOneWidget,
      );

      await pumpPreview(tester, deliveryManMetaRowAvailabilityOnly);
      expect(
        find.bySemanticsIdentifier('delivery_man_profile_availability'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('the label fails AA on the white profile surface', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManMetaRowRatingSummary);

      final ColorScheme scheme = AppTheme.light().colorScheme;
      final Color? label =
          tester.widget<Text>(find.text('4.3 . 113 Reviews')).style?.color;
      expect(label, scheme.onSecondaryContainer);

      // #777FC0 on #FFFFFF. `bodyMedium` is 14sp regular, so the threshold is
      final double ratio = _contrast(label!, scheme.surface);
      expect(ratio, closeTo(3.76, 0.05));
      expect(
        ratio,
        lessThan(4.5),
        reason: 'DEFECT: `onSecondaryContainer` is the periwinkle #777FC0 that '
            'the chat-banner and settlement audits already ruled out for text, '
            'and this row is body copy on the white profile surface. The '
            'sibling chip rendering the SAME ARB keys '
            '(CustomerProfileRating) uses `onSurfaceVariant` (#5C4038), which '
            'passes. When the role is corrected, flip this expectation to '
            'greaterThanOrEqualTo(4.5).',
      );
    });

    testWidgets('the "brand orange" glyph is navy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryManMetaRowRatingSummary);

      final ColorScheme scheme = AppTheme.light().colorScheme;
      final Color? icon = tester.widget<Icon>(find.byIcon(Icons.star)).color;

      expect(icon, scheme.primary);
      expect(
        icon,
        isNot(scheme.tertiary),
        reason: 'DEFECT: the class doc says the leading glyph is "brand orange '
            '(ColorScheme.primary per design §4)", but the b02 palette audit '
            'moved the brand orange (#D73B00) onto `tertiary` and left '
            '`primary` navy (#0B1351). The row still asks for `primary`, so '
            'the accent the design calls for never renders.',
      );
    });

    testWidgets('the icon does not grow with text scale', (
      WidgetTester tester,
    ) async {
      const String label = '4.3 . 113 Reviews';

      await pumpPreview(tester, deliveryManMetaRowRatingSummary);
      final Size iconAt100 = tester.getSize(find.byIcon(Icons.star));
      final double labelAt100 = tester.getSize(find.text(label)).height;
      expect(iconAt100, const Size(16, 16), reason: 'Sizes.medium');

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, deliveryManMetaRowRatingSummary);

      expect(
        tester.getSize(find.text(label)).height,
        greaterThan(labelAt100 * 1.5),
        reason: 'sanity check that the 200% rendering really is scaled',
      );
      expect(
        tester.getSize(find.byIcon(Icons.star)),
        iconAt100,
        reason: '`Icon.applyTextScaling` is left at its false default and '
            'nothing in AppTheme or OMDS sets it, so the glyph is frozen at '
            '16dp beside a label that has doubled — and it keeps 24pt of the '
            'column that the label, which is truncating, could have used.',
      );
    });

    testWidgets('Arabic mirrors the row and localizes the copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryManMetaRowRatingSummary,
        locale: const Locale('ar'),
      );

      expect(find.text('4.3 . 113 تقييم'), findsOneWidget);
      expect(find.textContaining('Reviews'), findsNothing);

      final Rect star = tester.getRect(find.byIcon(Icons.star));
      final Rect label = tester.getRect(find.text('4.3 . 113 تقييم'));
      expect(
        star.center.dx,
        greaterThan(label.center.dx),
        reason: 'the Row is order-based and the gap is a symmetric SizedBox, '
            'so the glyph must lead from the right in RTL',
      );

      await pumpPreview(
        tester,
        deliveryManMetaRowAvailabilityOnly,
        locale: const Locale('ar'),
      );
      expect(find.text('غير متاح'), findsOneWidget);
    });

    testWidgets('a free-text location stays Latin inside the Arabic row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryManMetaRowLocationAvailability,
        locale: const Locale('ar'),
      );

      // `location` is gateway free text and is routinely Latin script even in
      expect(find.text('Lebanon . متاح'), findsOneWidget);
    });

    testWidgets('every state fits the 390pt column at 100% text, except the '
        'small-phone one', (WidgetTester tester) async {
      // The control for the truncation asserted below: nothing here is broken
      for (final String state in const <String>[
        'Rating summary',
        'Cold start (D59)',
        'No reviews yet',
        'Location + availability',
        'Availability only (F9)',
      ]) {
        await pumpPreview(tester, _previews[state]!);
        expect(
          _truncated(tester, _labels[state]![0]),
          isFalse,
          reason: state,
        );
      }
    });

    testWidgets('the longest location loses its availability on a small phone',
        (WidgetTester tester) async {
      await pumpPreview(tester, deliveryManMetaRowLongestLocation);

      const String label = 'Bourj Hammoud, Mount Lebanon . Unavailable';
      expect(
        _truncated(tester, label),
        isTrue,
        reason: 'DEFECT (content, not code): 156pt of column after the glyph '
            'and its gap is not enough for a two-part location plus an '
            'availability label at the DEFAULT text size. `Text` ellipsizes '
            'the end, so what is dropped is the availability — the one fact on '
            'this row a client acts on.',
      );

      // And it drops content rather than growing: `overflow: ellipsis` wins
      expect(_paragraph(tester, label).size.height, lessThan(32));
    });

    testWidgets('at 200% text even the short production states truncate', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, deliveryManMetaRowLocationAvailability);
      expect(
        _truncated(tester, 'Lebanon . Available'),
        isTrue,
        reason: 'the plainest availability row in the app is ellipsized at the '
            'accessibility ceiling on a full-size phone',
      );
    });
  });
}
