import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_reviews_header.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_reviews_list.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  '113 reviews (production)': deliveryReviewsHeaderProduction,
  'Cold start · 0 reviews': deliveryReviewsHeaderColdStart,
  'Single review · "1 Reviews"': deliveryReviewsHeaderSingleReview,
  'Six figures · 320 pt': deliveryReviewsHeaderSixFigures,
  'Narrow · 200% text': deliveryReviewsHeaderNarrowLargeText,
  'Above the empty list': deliveryReviewsHeaderAboveEmptyList,
};

/// The widget's own geometry, restated from `delivery_reviews_h
const double _gutter = 20;
const double _titleToCount = 8;

/// The widths the previews pin into the tree. The render tests 
const double _phoneWidth = 390;
const double _narrowPhoneWidth = 320;

/// The button's [Key], from `_ViewAllButton`.
final Finder _viewAll = find.byKey(const Key('delivery-man-profile-view-all'));

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

/// How many lines [text] wrapped onto, counted from the laid-ou
int _lineCount(WidgetTester tester, String text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(text),
  );
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  expect(boxes, isNotEmpty, reason: '"$text" laid out no glyphs');
  return boxes.map((TextBox b) => b.top.round()).toSet().length;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryReviewsHeader',
    _previews,
    expectedText: const <String, String>{
      '113 reviews (production)': '113 Reviews',
      'Cold start · 0 reviews': '0 Reviews',
      'Single review · "1 Reviews"': '1 Reviews',
      'Six figures · 320 pt': '128450 Reviews',
      'Narrow · 200% text': '47 Reviews',
      'Above the empty list': 'No reviews yet',
    },
  );

  group('DeliveryReviewsHeader preview specifics', () {
    testWidgets('labels a single review "1 Reviews" (no ICU plural)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderSingleReview);

      expect(find.text('1 Reviews'), findsOneWidget);
      expect(
        find.text('1 Review'),
        findsNothing,
        reason: 'if this ever fails the ARB grew a plural select — delete this '
            'expectation and the note in the preview library doc, it was a bug '
            'not a contract',
      );
    });

    testWidgets('interpolates the count raw: no grouping, no digit shaping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderSixFigures);
      expect(find.text('128450 Reviews'), findsOneWidget);
      expect(
        find.text('128,450 Reviews'),
        findsNothing,
        reason: 'the placeholder declares `type: int` but no `format`, so no '
            'NumberFormat is applied',
      );

      await pumpPreview(
        tester,
        deliveryReviewsHeaderSixFigures,
        locale: const Locale('ar'),
      );
      expect(find.textContaining('128450'), findsOneWidget);
    });

    testWidgets('indents to the 20 pt gutter, 8 pt under the title', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderProduction);

      final Rect header = tester.getRect(find.byType(DeliveryReviewsHeader));
      final Rect title = tester.getRect(find.text('Reviews'));
      final Rect count = tester.getRect(find.text('113 Reviews'));
      final Rect button = tester.getRect(_viewAll);

      expect(header.width, _phoneWidth);
      expect(title.left - header.left, _gutter);
      expect(count.left - header.left, _gutter);
      expect(
        header.right - button.right,
        _gutter,
        reason: 'the affordance must land on the screen gutter, not float '
            'inside it',
      );

      expect(button.top - title.bottom, _titleToCount);

      expect(count.top - title.bottom, greaterThan(_titleToCount * 2));
      expect(count.center.dy, moreOrLessEquals(button.center.dy, epsilon: 0.5));
    });

    testWidgets('mirrors in Arabic: the button swaps edges with the count', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderProduction);
      final Rect enHeader = tester.getRect(find.byType(DeliveryReviewsHeader));
      final Rect enButton = tester.getRect(_viewAll);
      final Rect enCount = tester.getRect(find.text('113 Reviews'));

      await pumpPreview(
        tester,
        deliveryReviewsHeaderProduction,
        locale: const Locale('ar'),
      );
      final Rect arHeader = tester.getRect(find.byType(DeliveryReviewsHeader));
      final Rect arButton = tester.getRect(_viewAll);
      final Rect arCount = tester.getRect(find.text('113 تقييم'));

      expect(
        arButton.left - arHeader.left,
        _gutter,
        reason: 'Arabic must put "View all" on the LEFT gutter — if this fails '
            'the row is pinned LTR inside a right-to-left screen',
      );
      expect(
        arHeader.right - arCount.right,
        _gutter,
        reason: 'and the count on the right one',
      );

      expect(enHeader.right - enButton.right, _gutter);
      expect(enCount.left - enHeader.left, _gutter);
      expect(
        enButton.left - enHeader.left,
        greaterThan(arButton.left - arHeader.left + 100),
      );
    });

    testWidgets('at 320 pt / 200% the count pays, the button does not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderNarrowLargeText);

      expect(
        tester.takeException(),
        isNull,
        reason: 'the ceiling state must not paint an overflow stripe',
      );
      final Rect header = tester.getRect(find.byType(DeliveryReviewsHeader));
      expect(header.width, _narrowPhoneWidth);

      final Rect button = tester.getRect(_viewAll);
      final Rect count = tester.getRect(find.text('47 Reviews'));
      expect(
        button.width + count.width,
        lessThanOrEqualTo(_narrowPhoneWidth - 2 * _gutter + 0.5),
        reason: 'the row must stay inside the gutters',
      );
      expect(header.right - button.right, _gutter);

      expect(
        _lineCount(tester, '47 Reviews'),
        greaterThan(1),
        reason: 'at 2x on 320 pt the remaining width is too thin for one line',
      );

      await pumpPreview(tester, deliveryReviewsHeaderProduction);
      expect(_lineCount(tester, '113 Reviews'), 1);
    });

    testWidgets('abuts the list it heads, on the same gutter', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderAboveEmptyList);

      expect(find.text('0 Reviews'), findsOneWidget);
      expect(_viewAll, findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);

      final Rect header = tester.getRect(find.byType(DeliveryReviewsHeader));
      final Rect button = tester.getRect(_viewAll);
      final Rect list = tester.getRect(find.byType(DeliveryReviewsList));

      expect(header.bottom - button.bottom, 0);
      expect(list.top, header.bottom);
      expect(list.left, header.left);
      expect(list.width, header.width);
      expect(header.left, 0);
      expect(tester.getRect(find.text('0 Reviews')).left, _gutter);
    });

    testWidgets('"View all" keeps a 48 pt tap target', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderColdStart);

      expect(
        tester.getSize(_viewAll).height,
        greaterThanOrEqualTo(48.0),
        reason: 'a text-variant button still has to be hittable',
      );
    });

    test('the title ink clears AA in light and fails it badly in dark', () {
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.secondaryContainer, light.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'the light scheme hard-codes that role to the brand navy, so '
            'navy-on-white clears AA by a mile — it must not regress',
      );

      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        _contrast(dark.secondaryContainer, dark.surface),
        lessThan(3.0),
        reason: 'if this ever passes 3:1 the palette or the role was fixed — '
            'delete this expectation and the note in the preview library doc. '
            'Until then the "Reviews" heading is near-invisible in dark mode; '
            'the correct role is `onSurface`, never a `*Container` one '
            '(app_theme.dart says so itself).',
      );
    });

    test('the count ink misses AA in LIGHT — the default rendering', () {
      final ColorScheme light = AppTheme.light().colorScheme;
      final double onSurface = _contrast(
        light.onSecondaryContainer,
        light.surface,
      );
      expect(
        onSurface,
        lessThan(4.5),
        reason: 'muted purple #777FC0 on white is ~3.76:1, under the AA floor '
            'for 14 pt body text — if this ever fails the role or the palette '
            'was fixed, delete this expectation',
      );
      expect(onSurface, greaterThan(3.0));
      expect(
        _contrast(light.onSecondaryContainer, light.secondaryContainer),
        greaterThan(onSurface),
        reason: 'the colour is fine against the fill it was named for; the bug '
            'is the surface it is actually used on',
      );

      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        _contrast(dark.onSecondaryContainer, dark.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
