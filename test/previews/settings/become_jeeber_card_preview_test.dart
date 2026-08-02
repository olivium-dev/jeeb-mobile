// Render tests for the BecomeJeeberCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// BecomeJeeberCard has NO data inputs — its copy is fixed by the ARB and its
// only flag is `isAlreadyJeeber` — so three of the four previews render exactly
// the same words and differ only in the width they are laid out against. Text
// alone therefore cannot tell them apart, and a suite that stopped at
// `expectedText` would pass even if every preview were the 390 pt one. The
// `preview specifics` group below is the real discriminator: it pins the
// measured geometry of each width, which is also the defect this widget has.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/presentation/widgets/become_jeeber_card.dart';

import '../preview_test_harness.dart';

const String _title = 'Become a Jeeber';
const String _subtitle = 'Earn money delivering with Jeeb';
const String _cta = 'Start now';

/// Width of the card itself, i.e. the width its `Row` had to lay out in.
double _cardWidth(WidgetTester tester) =>
    tester.getSize(find.byType(BecomeJeeberCard)).width;

/// The rendered box of the title paragraph — the `Expanded` column's width and,
/// via its height, how many lines the title wrapped to (24 pt per line at 1×).
Size _titleBox(WidgetTester tester) => tester.getSize(find.text(_title));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'BecomeJeeberCard',
    const <String, Widget Function()>{
      'Client · 390': becomeJeeberCardPhone,
      'Narrow 320': becomeJeeberCardNarrowPhone,
      'Wide 700': becomeJeeberCardWide,
      'Already a Jeeber · hidden': becomeJeeberCardAlreadyJeeber,
    },
    expectedText: const <String, String>{
      // The title that wraps to three lines at this width.
      'Client · 390': _title,
      // The CTA that never yields, and so squeezes the text column to 41 pt.
      'Narrow 320': _cta,
      // The subtitle — the first thing to be squeezed away on a phone.
      'Wide 700': _subtitle,
      // Scaffolding text that exists ONLY in the hidden state, so this one
      // string genuinely fails if the wrong preview is rendered.
      'Already a Jeeber · hidden': 'Settings row below the card',
    },
  );

  group('BecomeJeeberCard preview specifics', () {
    // One pump per test, deliberately: the width states differ only in a
    // SizedBox constraint, so assertions are kept next to the pump that
    // produced them rather than chained through one tester.

    testWidgets('the phone state is laid out at 390 pt, not the 800 pt test '
        'surface', (WidgetTester tester) async {
      await pumpPreview(tester, becomeJeeberCardPhone);

      expect(_cardWidth(tester), 390);
    });

    testWidgets('at 390 pt the title already wraps to three lines', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, becomeJeeberCardPhone);

      final Size title = _titleBox(tester);
      // Measured: 111.1 × 72 (3 lines). The card is 204 pt tall as a result.
      expect(title.width, lessThan(130));
      expect(title.height, greaterThan(48));
      expect(tester.getSize(find.byType(BecomeJeeberCard)).height,
          greaterThan(150));
    });

    testWidgets('the narrow state really is laid out at 320 pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, becomeJeeberCardNarrowPhone);

      expect(_cardWidth(tester), 320);
    });

    testWidgets('at 320 pt the text column collapses and the title shreds', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, becomeJeeberCardNarrowPhone);

      final Size title = _titleBox(tester);
      // Measured: 41.1 × 168 — seven lines for two words.
      expect(title.width, lessThan(60));
      expect(title.height, greaterThan(96));
      // The CTA is unharmed: it is the text that pays for it.
      expect(find.text(_cta), findsOneWidget);
    });

    testWidgets('at 700 pt the same copy fits on one line — the copy was never '
        'the problem', (WidgetTester tester) async {
      await pumpPreview(tester, becomeJeeberCardWide);

      expect(_cardWidth(tester), 700);
      // Measured: 242.3 × 24 (one line), card 96 pt tall.
      expect(_titleBox(tester).height, lessThan(48));
      expect(
        tester.getSize(find.byType(BecomeJeeberCard)).height,
        lessThan(120),
      );
    });

    testWidgets('the hidden state collapses to nothing (T-MOB-027 AC2)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, becomeJeeberCardAlreadyJeeber);

      expect(find.byKey(BecomeJeeberCard.rootKey), findsNothing);
      expect(find.byKey(BecomeJeeberCard.ctaKey), findsNothing);
      expect(find.text(_title), findsNothing);
      expect(find.text(_cta), findsNothing);
      // Zero height, not merely invisible: no ghost padding left behind.
      expect(tester.getSize(find.byType(BecomeJeeberCard)).height, 0);
      // ...and the neighbours are still there, so an empty canvas cannot be
      // mistaken for a preview that failed to build.
      expect(find.text('Settings row above the card'), findsOneWidget);
      expect(find.text('Settings row below the card'), findsOneWidget);
    });

    // KNOWN DEFECT GUARD — delete this test when the card is fixed.
    //
    // The preview matrix renders every state at 200% text, but the canvas is
    // the only place that happens; these render tests run at 1×, so the worst
    // state this widget has would otherwise be asserted nowhere. At 200% the
    // CTA label grows to ~253 pt and the avatar takes ~72 pt more, driving the
    // `Expanded` text column to ZERO width — the title and subtitle disappear
    // entirely — and the Row still overflows the phone by 15 pt (85 pt at
    // 320). Fixing the card (wrapping the Row, or dropping to a Column above a
    // width threshold) will fail this test; that is the point.
    testWidgets('at 200% text the card row overflows and loses its text', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        previewCanvas(becomeJeeberCardPhone, const Locale('en')),
      );
      await tester.pump();

      final Object? error = tester.takeException();
      expect(error, isNotNull, reason: 'the Row is expected to overflow');
      expect(error.toString(), contains('overflowed'));
      // The text column is not merely cropped — it is allocated no width.
      expect(_titleBox(tester).width, 0);
    });
  });
}
