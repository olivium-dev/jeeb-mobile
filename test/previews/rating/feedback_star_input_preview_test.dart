// Render tests for the FeedbackStarInput previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT title, because a
// suite that only asked "did something render?" would pass on five copies of
// the same row.
//
// FeedbackStarInput renders no text at all — five glyphs and nothing else — so
// the title alone would be a weak pin: it lives in the preview's specimen, not
// in the widget. The `fill` group below therefore counts filled vs empty stars
// per state, which is the only thing the widget itself puts on screen, and the
// `geometry` group measures the row the way a reviewer squints at the canvas.
// Both of those groups also pin behaviour that is currently WRONG (see the
// comments on each); they are regression pins, not endorsements.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';

import '../preview_test_harness.dart';

/// `OmdsStarRating` renders empty stars as [Icons.star_border] and filled ones
/// as [Icons.star]; there is no other signal, in the widget or in semantics,
/// that says how many are selected.
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
      // difference between a screen that will not submit and one that will.
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
      // paints EXACTLY what a genuine five-star rating paints — the readout is
      // the only thing on screen that can tell the two apart, and the readout
      // belongs to this preview, not to the widget. Upstream, the score payload
      // is parsed with `(raw as num?)?.toInt() ?? 0` and clamped nowhere.
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
      // tappable glyphs are the borders (same trick as feedback_screen_test).
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
      // box — OmdsStarRating puts the 4 dp spacer OUTSIDE the icon and
      // RenderPadding does not hit-test its own padding. So all five targets
      // are 40 x 40 against a 48 dp floor (A11y.minTapTargetSize, AC
      // T-mobile-036), and nothing wraps them in MinTapTarget.
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
      // scaler does not touch them: at the 200% ceiling the AC asks for, the
      // label describing this control doubles and the control does not move.
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
      // instead of `EdgeInsetsDirectional.only(end: …)`. The Row mirrors, the
      // padding does not, so the whole gap sequence slides one glyph over: a
      // stray 4 dp inset appears on the leading (right) edge and the gap
      // between the 4th and 5th stars disappears entirely.
      //
      // REGRESSION PIN, NOT AN ENDORSEMENT: when OMDS switches to
      // EdgeInsetsDirectional these expectations become [4, 4, 4, 4] and 0/4,
      // matching the LTR test above. Update them then — the fix is upstream in
      // omds_library/lib/src/reviews/omds_star_rating.dart, not here.
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
      // verification runs BEFORE tearDowns and fails on a live handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, feedbackStarInputUnrated);

      final SemanticsData data = tester
          .getSemantics(find.byKey(FeedbackStarInput.rootKey))
          .getSemanticsData();

      // The widget claims the slider role and publishes a value...
      expect(data.flagsCollection.isSlider, isTrue);
      expect(data.value, '0 / 5');

      // ...but wires up neither adjust action, so a screen reader offers
      // "swipe up/down to adjust" on a control where that does nothing. The
      // only way to set a rating is to hit one of the 40 dp stars. There is no
      // label either: the node announces "0 / 5" with nothing to say it is a
      // rating, and "/ 5" is not localized copy.
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
