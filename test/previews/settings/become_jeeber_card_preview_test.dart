// Render tests for the BecomeJeeberCard previews.

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
      'Already a Jeeber · hidden': 'Settings row below the card',
    },
  );

  group('BecomeJeeberCard preview specifics', () {
    // One pump per test, deliberately: the width states differ only in a

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
      expect(find.text('Settings row above the card'), findsOneWidget);
      expect(find.text('Settings row below the card'), findsOneWidget);
    });

    // KNOWN DEFECT GUARD — delete this test when the card is fixed.
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
