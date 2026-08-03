// Render tests for the FeedbackStarInput previews.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';

import '../preview_test_harness.dart';

/// `OmdsStarRating` renders empty stars as [Icons.star_border] and filled ones
/// as [Icons.star]; there is no other signal, in the widget or in semantics,
Finder get _filled => find.byIcon(Icons.star);
Finder get _empty => find.byIcon(Icons.star_border);

/// The five glyphs in tree order (index 0 = the first child of the row, which
/// is the LEFT-most star in LTR and the RIGHT-most in RTL).
Finder get _stars => find.descendant(
      of: find.byType(FeedbackStarInput),
      matching: find.byType(Icon),
    );

List<Rect> _starRects(WidgetTester tester) =>
    List<Rect>.generate(5, (int i) => tester.getRect(_stars.at(i)));

/// Gaps between adjacent glyphs, in reading order, so LTR and RTL are directly
/// comparable: `gaps[i]` is the space between star `i` and star `i + 1`.
List<double> _gaps(List<Rect> rects, {required bool rtl}) => <double>[
      for (int i = 0; i < rects.length - 1; i++)
        rtl ? rects[i].left - rects[i + 1].right : rects[i + 1].left - rects[i].right,
    ];

/// Renders [preview] at the phone width the previews declare rather than the
/// 800 pt default test surface.
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpPreview(tester, preview, locale: locale);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'FeedbackStarInput',
    const <String, Widget Function()>{
      'Unrated': feedbackStarInputUnrated,
      'One star': feedbackStarInputOneStar,
      'Three of five': feedbackStarInputThreeOfFive,
      'All five': feedbackStarInputAllFive,
      'Out of range': feedbackStarInputOutOfRange,
    },
    expectedText: const <String, String>{
      'Unrated': 'Unrated',
      'One star': 'One star',
      'Three of five': 'Three of five',
      'All five': 'All five',
      'Out of range': 'Out of range',
    },
  );

  group('FeedbackStarInput preview fill', () {
    testWidgets('Unrated paints five outlines and nothing filled', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackStarInputUnrated);

      expect(_filled, findsNothing);
      expect(_empty, findsNWidgets(5));
      expect(find.text('value 0 / 5'), findsOneWidget);
    });

    testWidgets('One star fills exactly one glyph', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackStarInputOneStar);

      // The hardest reading in the set: one 40 dp glyph is the entire
      expect(_filled, findsOneWidget);
      expect(_empty, findsNWidgets(4));
      expect(find.text('value 1 / 5'), findsOneWidget);
    });

    testWidgets('Three of five exercises both branches of the fill test', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackStarInputThreeOfFive);

      expect(_filled, findsNWidgets(3));
      expect(_empty, findsNWidgets(2));
      expect(find.text('value 3 / 5'), findsOneWidget);
    });

    testWidgets('All five fills the row', (WidgetTester tester) async {
      await pumpPreview(tester, feedbackStarInputAllFive);

      expect(_filled, findsNWidgets(5));
      expect(_empty, findsNothing);
      expect(find.text('value 5 / 5'), findsOneWidget);
    });

    testWidgets('an out-of-range value is rendered, not rejected', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackStarInputOutOfRange);

      // `stars` is an unvalidated int. 9 asserts nothing, throws nothing and
      expect(tester.takeException(), isNull);
      expect(_filled, findsNWidgets(5));
      expect(_empty, findsNothing);
      expect(find.text('value 9 / 5'), findsOneWidget);
    });

    testWidgets('tapping a star drives onChanged back into the row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackStarInputUnrated);

      // Tap the 4th star. At rating 0 every star is an outline, so the
      await tester.tap(_empty.at(3));
      await tester.pumpAndSettle();

      expect(find.text('value 4 / 5'), findsOneWidget);
      expect(_filled, findsNWidgets(4));
      expect(_empty, findsOneWidget);
    });
  });

  group('FeedbackStarInput preview geometry', () {
    testWidgets('every star is 8 dp under the minimum tap target', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(tester, feedbackStarInputThreeOfFive);

      // `starSize: Sizes.threeXLarge` is 40, and the glyph is the whole hit
      for (final Rect rect in _starRects(tester)) {
        expect(rect.size, const Size(40, 40));
        expect(rect.height, lessThan(A11y.minTapTargetSize));
      }
    });

    testWidgets('the row is the same 216 x 40 at 100% and at 200% text', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(tester, feedbackStarInputThreeOfFive);
      final Size atNormal = tester.getSize(find.byType(OmdsStarRating));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: previewCanvas(feedbackStarInputThreeOfFive, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      // 5 x 40 + 4 x 4. Icon sizes are logical pixels, not text, so the text
      expect(atNormal, const Size(216, 40));
      expect(tester.getSize(find.byType(OmdsStarRating)), atNormal);
    });

    testWidgets('LTR spaces the row evenly', (WidgetTester tester) async {
      await _pumpOnPhone(tester, feedbackStarInputThreeOfFive);

      final List<Rect> rects = _starRects(tester);
      final Rect row = tester.getRect(find.byType(OmdsStarRating));

      expect(_gaps(rects, rtl: false), <double>[4, 4, 4, 4]);
      // Flush on both edges: the trailing star carries no spacer.
      expect(rects.first.left - row.left, 0);
      expect(row.right - rects.last.right, 0);
    });

    testWidgets('RTL does NOT mirror the spacing — last two stars touch', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(
        tester,
        feedbackStarInputThreeOfFive,
        locale: const Locale('ar'),
      );

      final List<Rect> rects = _starRects(tester);
      final Rect row = tester.getRect(find.byType(OmdsStarRating));

      // OmdsStarRating spaces with a PHYSICAL `EdgeInsets.only(right: …)`
      expect(_gaps(rects, rtl: true), <double>[4, 4, 4, 0]);
      expect(row.right - rects.first.right, 4);
      expect(rects.last.left - row.left, 0);
    });
  });

  group('FeedbackStarInput preview semantics', () {
    testWidgets('announces a slider it gives no way to adjust', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, feedbackStarInputUnrated);

      final SemanticsData data = tester
          .getSemantics(find.byKey(FeedbackStarInput.rootKey))
          .getSemanticsData();

      // The widget claims the slider role and publishes a value...
      expect(data.flagsCollection.isSlider, isTrue);
      expect(data.value, '0 / 5');

      // ...but wires up neither adjust action, so a screen reader offers
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      expect(data.label, isEmpty);

      handle.dispose();
    });

    testWidgets('the published value tracks the row', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, feedbackStarInputThreeOfFive);
      expect(
        tester
            .getSemantics(find.byKey(FeedbackStarInput.rootKey))
            .getSemanticsData()
            .value,
        '3 / 5',
      );

      handle.dispose();
    });
  });
}
