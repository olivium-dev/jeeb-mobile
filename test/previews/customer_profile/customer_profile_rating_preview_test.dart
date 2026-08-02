// Render tests for the CustomerProfileRating previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with two deviations, both on
// purpose:
//
//   * It loads the production Inter faces (and, through the same helper, the
//     deterministic Arabic subset the goldens use). Every width below is a
//     device number; under the square test font they are all roughly double,
//     and every state would look truncated.
//   * Two states — 'Unrated (cold start)' and 'Reviews, no average' — share the
//     string "No reviews yet" in the `expectedText` map, because the widget
//     folds two different payloads onto identical output. That is the defect,
//     not a lazy fixture, so those two are told apart underneath by asserting
//     what each one must NOT say.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_rating.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Rated (production)': customerProfileRatingRated,
  'Unrated (cold start)': customerProfileRatingUnrated,
  'Reviews, no average': customerProfileRatingCountWithoutAverage,
  'Single review': customerProfileRatingSingleReview,
  'Zero score, rated': customerProfileRatingZeroScore,
  'Longest plausible (small phone)': customerProfileRatingLongest,
};

/// The label each state renders, `[en, ar]`. Written out rather than derived so
/// a copy change has to be acknowledged here.
const Map<String, List<String>> _labels = <String, List<String>>{
  'Rated (production)': <String>['4.9 . 312 Reviews', '4.9 . 312 تقييم'],
  'Unrated (cold start)': <String>['No reviews yet', 'لا توجد تقييمات بعد'],
  'Reviews, no average': <String>['No reviews yet', 'لا توجد تقييمات بعد'],
  'Single review': <String>['5.0 . 1 Reviews', '5.0 . 1 تقييم'],
  'Zero score, rated': <String>['0.0 . 3 Reviews', '0.0 . 3 تقييم'],
  'Longest plausible (small phone)': <String>[
    '5.0 . 1284 Reviews',
    '5.0 . 1284 تقييم',
  ],
};

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

/// Whether [text] was ellipsized rather than shown in full.
bool _truncated(WidgetTester tester, String text) =>
    _paragraph(tester, text).didExceedMaxLines;

/// How many lines [text] laid out onto, counted from the glyph boxes.
int _lineCount(WidgetTester tester, String text) {
  final List<TextBox> boxes = _paragraph(tester, text).getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((TextBox b) => b.top.round()).toSet().length;
}

void main() {
  setUpAll(() async {
    loadPreviewArbs();
    // Geometry, not glyphs, is what the states below are for — the widths are
    // meaningless under the square test font.
    await loadInterTestFont();
  });

  testPreviewsRender(
    'CustomerProfileRating',
    _previews,
    expectedText: const <String, String>{
      'Rated (production)': '4.9 . 312 Reviews',
      'Unrated (cold start)': 'No reviews yet',
      // Same copy as the state above — see the header note; pinned apart below.
      'Reviews, no average': 'No reviews yet',
      'Single review': '5.0 . 1 Reviews',
      'Zero score, rated': '0.0 . 3 Reviews',
      'Longest plausible (small phone)': '5.0 . 1284 Reviews',
    },
  );

  group('CustomerProfileRating preview specifics', () {
    testWidgets('the star is solid iff the payload carries BOTH fields', (
      WidgetTester tester,
    ) async {
      for (final String state in const <String>[
        'Rated (production)',
        'Single review',
        'Zero score, rated',
        'Longest plausible (small phone)',
      ]) {
        await pumpPreview(tester, _previews[state]!);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget, reason: state);
        expect(
          find.byIcon(Icons.star_border_rounded),
          findsNothing,
          reason: state,
        );
      }

      for (final String state in const <String>[
        'Unrated (cold start)',
        'Reviews, no average',
      ]) {
        await pumpPreview(tester, _previews[state]!);
        expect(
          find.byIcon(Icons.star_border_rounded),
          findsOneWidget,
          reason: state,
        );
      }
    });

    testWidgets('a count with no average denies the reviews it has', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRatingCountWithoutAverage);

      // `_hasRating` is one `&&` over two independent getMe fields, so a
      // payload carrying 42 ratings without an aggregated average takes the
      // cold-start branch and asserts the opposite of what it knows.
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(
        find.textContaining('42'),
        findsNothing,
        reason: 'the account has 42 ratings and the header says it has none; '
            'nothing on screen carries the count that WAS delivered',
      );
    });

    testWidgets('the unrated chip still emits its Maestro identifier', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, customerProfileRatingUnrated);
      expect(
        find.bySemanticsIdentifier('customer_profile_rating'),
        findsOneWidget,
        reason: 'the whole reason the chip renders in the empty state is that '
            '.maestro/flows/jm-035-customer-profile.yaml asserts this id for '
            'every account',
      );

      handle.dispose();
    });

    testWidgets('a single review is shown as a score (D59 says it must not)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRatingSingleReview);

      // D59: hide the aggregate until N >= 5. `DeliveryManProfileHeader.
      // _RatingRow` implements it (isColdStart -> deliveryManProfileReviewsCount,
      // no score); this widget renders the score from the first review, out of
      // the same two ARB keys.
      expect(find.text('5.0 . 1 Reviews'), findsOneWidget);
      expect(
        find.byIcon(Icons.star_rounded),
        findsOneWidget,
        reason: 'a solid brand star over a single unverified rating',
      );

      // And the label reads "1 Reviews": AppLocalizations resolves keys by
      // `replaceFirst('{count}', '$count')`, so there is no ICU plural to reach
      // for even if the ARB grew one.
      expect(find.textContaining('1 Reviews'), findsOneWidget);
    });

    testWidgets('4.96 is presented as a perfect 5.0, over an ungrouped count', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRatingLongest);

      // `toStringAsFixed(1)` rounds up: the imperfect account reads perfect.
      expect(find.text('5.0 . 1284 Reviews'), findsOneWidget);
      expect(find.textContaining('4.9'), findsNothing);
      expect(
        find.textContaining('1,284'),
        findsNothing,
        reason: 'the count is interpolated as a raw int, so no locale-aware '
            'grouping is applied in either locale',
      );
    });

    testWidgets('Arabic mirrors the row and localizes the copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        customerProfileRatingRated,
        locale: const Locale('ar'),
      );

      expect(find.text('4.9 . 312 تقييم'), findsOneWidget);
      expect(find.textContaining('Reviews'), findsNothing);

      final Rect star = tester.getRect(find.byIcon(Icons.star_rounded));
      final Rect label = tester.getRect(find.text('4.9 . 312 تقييم'));
      expect(
        star.center.dx,
        greaterThan(label.center.dx),
        reason: 'the Row is order-based and the gap is a symmetric SizedBox, so '
            'the star must lead from the right in RTL',
      );

      await pumpPreview(
        tester,
        customerProfileRatingUnrated,
        locale: const Locale('ar'),
      );
      expect(find.text('لا توجد تقييمات بعد'), findsOneWidget);
    });

    testWidgets('every state fits its column at 100% text, in both locales', (
      WidgetTester tester,
    ) async {
      // The control for the truncation asserted below: nothing here is broken
      // at the default text size, so the failures at 200% are the scale's doing
      // and not a fixture that was too long to begin with.
      for (final MapEntry<String, List<String>> entry in _labels.entries) {
        for (int i = 0; i < 2; i++) {
          final Locale locale = i == 0 ? const Locale('en') : const Locale('ar');
          await pumpPreview(tester, _previews[entry.key]!, locale: locale);
          expect(
            _truncated(tester, entry.value[i]),
            isFalse,
            reason: '${entry.key} · ${locale.languageCode}',
          );
          expect(_lineCount(tester, entry.value[i]), 1);
        }
      }
    });

    testWidgets('at 200% text the label truncates instead of wrapping', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      // English on a 390pt phone survives: 209pt of label in the 226pt the
      // 250pt identity column leaves after the star and its gap.
      await pumpPreview(tester, customerProfileRatingRated);
      expect(_truncated(tester, '4.9 . 312 Reviews'), isFalse);

      // Arabic does not. The cold-start copy is the widest string this widget
      // can render ("لا توجد تقييمات بعد" against "No reviews yet"), and it is
      // the EMPTY state — the one every unrated account lands on.
      await pumpPreview(
        tester,
        customerProfileRatingUnrated,
        locale: const Locale('ar'),
      );
      expect(
        _truncated(tester, 'لا توجد تقييمات بعد'),
        isTrue,
        reason: 'the Arabic empty state is ellipsized inside the identity '
            'column at the accessibility ceiling, on a full-size phone',
      );

      // And the longest label on the smallest phone loses its review count.
      // `Text` ellipsizes the END, so what survives is the score and what is
      // cut is the number of ratings backing it.
      const List<String> longest = <String>[
        '5.0 . 1284 Reviews',
        '5.0 . 1284 تقييم',
      ];
      for (int i = 0; i < 2; i++) {
        final Locale locale = i == 0 ? const Locale('en') : const Locale('ar');
        await pumpPreview(
          tester,
          customerProfileRatingLongest,
          locale: locale,
        );
        final String label = longest[i];
        expect(_truncated(tester, label), isTrue, reason: locale.languageCode);
        expect(
          _lineCount(tester, label),
          1,
          reason: '`overflow: TextOverflow.ellipsis` wins over the null '
              'maxLines: the chip stays one line and drops content rather '
              'than growing, so nothing on the header signals the loss',
        );
      }
    });

    testWidgets('the chip stays inside the column it is given', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRatingRated);
      final double shortWidth =
          tester.getSize(find.byType(CustomerProfileRating)).width;

      await pumpPreview(tester, customerProfileRatingLongest);
      final double smallPhoneWidth =
          tester.getSize(find.byType(CustomerProfileRating)).width;

      // `Flexible` + `MainAxisSize.min` means the row shrink-wraps its label
      // and stops at the column width. This half of the layout is fine, and
      // pinning it is what makes the truncation above attributable to the text.
      expect(shortWidth, lessThanOrEqualTo(250.0));
      expect(smallPhoneWidth, lessThanOrEqualTo(180.0));
    });

    testWidgets('the star does not grow with text scale', (
      WidgetTester tester,
    ) async {
      const String label = '4.9 . 312 Reviews';

      await pumpPreview(tester, customerProfileRatingRated);
      final Size starAt100 = tester.getSize(find.byIcon(Icons.star_rounded));
      final double labelAt100 = tester.getSize(find.text(label)).height;
      expect(starAt100, const Size(20, 20), reason: 'Sizes.large');

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, customerProfileRatingRated);

      expect(
        tester.getSize(find.text(label)).height,
        greaterThan(labelAt100 * 1.5),
        reason: 'sanity check that the 200% rendering really is scaled',
      );
      expect(
        tester.getSize(find.byIcon(Icons.star_rounded)),
        starAt100,
        reason: '`Icon.applyTextScaling` is left at its false default and '
            'nothing in AppTheme or OMDS sets it, so the star is frozen at '
            '20dp beside a label that has doubled — and it keeps 24pt of the '
            'column that the label, which is truncating, could have used',
      );
    });
  });
}
