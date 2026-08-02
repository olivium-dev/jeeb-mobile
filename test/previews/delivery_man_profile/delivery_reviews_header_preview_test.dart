// Render tests for the DeliveryReviewsHeader previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The `expectedText` map below binds each state to a string only that state
// puts on screen — six different counts, plus the empty list's own title — so a
// suite that accidentally rendered the same header six times fails instead of
// passing. Underneath it, the specifics group pins the three things this widget
// is really made of and that `find.text` cannot see: the count/button split,
// the mirroring, and the ink roles.

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

/// The widget's own geometry, restated from `delivery_reviews_header.dart`
/// (`Spacing.large` / `Spacing.xSmall`) so a change to either shows up here as
/// a failure rather than as a silent redesign.
const double _gutter = 20;
const double _titleToCount = 8;

/// The widths the previews pin into the tree. The render tests pump onto an
/// 800 × 600 surface, so these are the only reason a "320 pt" state is one.
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

/// How many lines [text] wrapped onto, counted from the laid-out glyph boxes.
///
/// Line COUNTS rather than pixel heights: `flutter_test` substitutes its own
/// metrics for Inter, so an absolute height measured here would be a property
/// of the test font rather than of the layout.
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
      // One count per state, so no two states can be confused for each other.
      '113 reviews (production)': '113 Reviews',
      'Cold start · 0 reviews': '0 Reviews',
      // The defect itself is the pin — see the specifics group below.
      'Single review · "1 Reviews"': '1 Reviews',
      'Six figures · 320 pt': '128450 Reviews',
      'Narrow · 200% text': '47 Reviews',
      // This state also says "0 Reviews"; keying on the empty list's own title
      // is what tells it apart from the cold-start state above.
      'Above the empty list': 'No reviews yet',
    },
  );

  group('DeliveryReviewsHeader preview specifics', () {
    testWidgets('labels a single review "1 Reviews" (no ICU plural)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderSingleReview);

      // Documents today's behaviour rather than endorsing it.
      // `deliveryManProfileReviewsCount` is `"{count} Reviews"` with a plain
      // `int` placeholder, resolved by `replaceFirst('{count}', '$count')` —
      // there is no `plural` select to pick a singular form. Every jeeber hits
      // this on their first rating.
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

      // Arabic gets the same Western digits inside the Arabic string, because
      // the value is interpolated with `'$count'` before the ARB is touched.
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

      // The `Spacing.xSmall` gap is measured to the ROW, and the row is 48 pt
      // tall because the button sets that height — so the button's top is the
      // row's top.
      expect(button.top - title.bottom, _titleToCount);

      // What a reader actually sees is not 8 pt: the count is centred in that
      // 48 pt row, so the optical gap under the title is ~22. Pinned because it
      // is the number a designer would query, and because it moves the moment
      // anyone changes the button's height rather than the spacing token.
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
      // Measured against the header's OWN box in each direction: the preview's
      // `AlignmentDirectional.topStart` host is itself mirrored, so the 390 pt
      // box sits on the right of the 800 pt test surface in Arabic.
      final Rect arHeader = tester.getRect(find.byType(DeliveryReviewsHeader));
      final Rect arButton = tester.getRect(_viewAll);
      // The ARB value the screen already ships.
      final Rect arCount = tester.getRect(find.text('113 تقييم'));

      // `EdgeInsetsDirectional` + `spaceBetween` are supposed to mirror the
      // whole row, not just flip the text inside it.
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

      // The same two measurements in English, so the assertion above cannot
      // pass by the row being symmetric.
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
      // The host really is the narrow phone, not the 800 pt test surface.
      final Rect header = tester.getRect(find.byType(DeliveryReviewsHeader));
      expect(header.width, _narrowPhoneWidth);

      // `OmdsPrimaryButton` defaults to `width: null`, so it is laid out with
      // unbounded main-axis constraints and keeps its full intrinsic width; the
      // `Flexible` count gets the remainder. That priority is the decision this
      // preview exists to show.
      final Rect button = tester.getRect(_viewAll);
      final Rect count = tester.getRect(find.text('47 Reviews'));
      expect(
        button.width + count.width,
        lessThanOrEqualTo(_narrowPhoneWidth - 2 * _gutter + 0.5),
        reason: 'the row must stay inside the gutters',
      );
      expect(header.right - button.right, _gutter);

      // The count has no `maxLines` and no `overflow`, so it degrades by
      // wrapping. Add either and this becomes an ellipsis and the count stops
      // growing.
      expect(
        _lineCount(tester, '47 Reviews'),
        greaterThan(1),
        reason: 'at 2x on 320 pt the remaining width is too thin for one line',
      );

      // Same header, same copy, no scale — the comparison that shows the wrap
      // is the scale and not the string.
      await pumpPreview(tester, deliveryReviewsHeaderProduction);
      expect(_lineCount(tester, '113 Reviews'), 1);
    });

    testWidgets('abuts the list it heads, on the same gutter', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReviewsHeaderAboveEmptyList);

      // The state a brand-new jeeber's profile really shows: a live "View all"
      // over "No reviews yet".
      expect(find.text('0 Reviews'), findsOneWidget);
      expect(_viewAll, findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);

      final Rect header = tester.getRect(find.byType(DeliveryReviewsHeader));
      final Rect button = tester.getRect(_viewAll);
      final Rect list = tester.getRect(find.byType(DeliveryReviewsList));

      // The header reserves nothing below its count row: it ends flush with the
      // 48 pt button. Every pixel of air under it therefore belongs to the LIST
      // — `Spacing.large` in this empty branch, `Spacing.medium` in the
      // populated one — which is why the two have to be read together.
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
      // The title paints with `colorScheme.secondaryContainer` — a container
      // role, i.e. a fill meant to sit BEHIND ink.
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
      // The count line inks with `onSecondaryContainer`, a colour picked to sit
      // ON the navy `secondaryContainer` fill — but it is painted on the plain
      // `surface`, where that pairing was never checked.
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

      // Dark inverts the pair: `fromSeed` gives `onSecondaryContainer` a light
      // tone, so the count is the legible half of the header there and the
      // title is the broken one.
      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        _contrast(dark.onSecondaryContainer, dark.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
