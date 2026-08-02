// Render tests for the SettlementDetailScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, which matters more for a screen than for
// a widget: all six previews are the same screen behind the same app bar,
// differing only in the statement value handed to it. A suite that asserted
// "the app bar rendered" would pass with every preview wired to the same
// fixture.
//
// One preview is not in the shared suite and has a group of its own:
// `LBP · compact 320` renders the SAME statement as `LBP · six lines`, so no
// string can tell them apart — the difference is the surface it is pumped at,
// and that is what its group asserts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settlement/presentation/settlement_detail_screen.dart';

import '../preview_test_harness.dart';

/// The box `LBP · compact 320` declares
/// (`_settlementDetailScreenCompactBox`). The harness pumps at the
/// `flutter_test` default of 800x600, which is two and a half times the
/// narrowest supported phone.
const Size _compactBox = Size(320, 568);

/// The box the other five previews declare
/// (`_settlementDetailScreenPhoneBox`).
const Size _phoneBox = Size(390, 844);

/// Pumps [preview] at [box] and returns every overflow that frame reported.
///
/// Intercepting `FlutterError.onError` is what makes a MULTI-overflow state
/// assertable at all. `tester.takeException()` returns only the first pending
/// exception, and once a second arrives the binding replaces it with the string
/// `'Multiple exceptions (2) were detected…'` — which no longer names the row
/// that produced it, and is not a `FlutterError`, so neither `isFlutterError`
/// nor `contains('overflowed')` can match it. Both rows on this screen overflow
/// at 320 pt, so this is load-bearing here rather than a nicety.
///
/// Draining the errors through `onError` also leaves the test with no pending
/// exception, which is what lets these tests assert the defect instead of dying
/// of it.
Future<List<String>> _overflowsAt(
  WidgetTester tester,
  Widget Function() preview,
  Size box, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(box);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final List<String> seen = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    seen.add(details.exceptionAsString());
  };
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
  FlutterError.onError = previous;

  return seen
      .where((String s) => s.contains('overflowed'))
      .toList(growable: false);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SettlementDetailScreen',
    const <String, Widget Function()>{
      'Paid · two deliveries': settlementDetailScreenPaid,
      'Pending · one delivery': settlementDetailScreenPending,
      'Empty · no delivery lines': settlementDetailScreenNoDeliveries,
      'LBP · six lines': settlementDetailScreenLbp,
      'Partial payload · blank title':
          settlementDetailScreenPartialPayload,
    },
    expectedText: const <String, String>{
      // The headline payout. Not the week label — `Jun 22 – Jun 28` and
      // `Jun 29 – Jul 5` differ by four characters and would be a fragile pin.
      'Paid · two deliveries': 'USD 184.50',
      'Pending · one delivery': 'USD 96.00',
      // This one PINS THE TITLE on purpose: the payout is `USD 0.00`, which the
      // partial-payload state could plausibly acquire too, and the week label is
      // the only thing this statement has that no other fixture carries.
      'Empty · no delivery lines': 'Jul 6 – Jul 12',
      // Eight digits, hand-formatted with two forced decimals and no grouping
      // separator — the shape the screen actually prints.
      'LBP · six lines': 'LBP 12555000.00',
      'Partial payload · blank title': 'USD 42.75',
    },
  );

  // The narrow-surface twin of `LBP · six lines`. Same statement, so the shared
  // suite cannot distinguish them; what it renders differently is the width
  // budget in `_DeliveryLineRow`, and 320 pt is the device that runs out first.
  //
  // It runs out badly enough to throw. This preview does not render cleanly at
  // its declared box and is not meant to — it is the state that demonstrates
  // the two unconstrained `Row`s described in the preview section, so these
  // tests pin the overflow rather than asserting it away.
  group('SettlementDetailScreen previews · LBP · compact 320', () {
    // KNOWN DEFECT, both locales. At 320 pt the screen reports TWO overflows per
    // frame:
    //
    //  * `_SummaryCard`'s header `Row` (settlement_detail_screen.dart:71) — a
    //    label and a status chip under `spaceBetween` with no flexible child
    //    between them: 44 px over in EN, 96 px in AR, where the label is the
    //    longer "إجمالي النقد المحتفظ به".
    //  * `_DeliveryLineRow` (settlement_detail_screen.dart:131) — only the LEFT
    //    column is `Expanded`, so the eight-digit amounts column is measured
    //    first against an unbounded constraint and cannot wrap or ellipsize.
    //
    // If either of these starts coming back EMPTY the screen has been fixed:
    // delete that half here and strike the matching bullet from the JEEB
    // PREVIEWS section of
    // `lib/features/settlement/presentation/settlement_detail_screen.dart`.
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'KNOWN DEFECT: at 320 pt both rows overflow · ${locale.languageCode}',
        (WidgetTester tester) async {
          final List<String> overflows = await _overflowsAt(
            tester,
            settlementDetailScreenLbpCompact,
            _compactBox,
            locale: locale,
          );

          expect(
            overflows,
            isNotEmpty,
            reason: 'the narrowest supported phone is where the summary header '
                'and the amounts column both run out of width',
          );
          // Not "an overflow happened" but "both rows overflowed": one of these
          // being fixed must not let the other pass unnoticed.
          expect(overflows.length, greaterThanOrEqualTo(2));
          expect(
            overflows.every((String s) => s.contains('on the right')),
            isTrue,
            reason: 'both are horizontal Rows overrunning their main axis',
          );
        },
      );
    }

    testWidgets('LBP · compact 320 renders its own state', (
      WidgetTester tester,
    ) async {
      // Same statement as `LBP · six lines`, so this pins the surface, not the
      // strings — the strings are identical by construction.
      await _overflowsAt(
        tester,
        settlementDetailScreenLbpCompact,
        _compactBox,
      );

      expect(find.text('LBP 12555000.00'), findsOneWidget);
      // The amounts column is never TRUNCATED — it is the non-flexible child,
      // so it takes the width it wants and the date/tier column gets whatever
      // is left. The text is all present in the tree; what 320 pt costs is that
      // some of it is painted outside the row rather than dropped, which is
      // exactly why `find.text` still passes while the frame throws.
      expect(find.text('LBP 2025000.00'), findsOneWidget);
      expect(find.text('Platform fee: LBP 225000.00'), findsOneWidget);
    });
  });

  group('SettlementDetailScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree
    // — `Navigator` → `SettlementDetailScreen` — differing only in the
    // statement, so pumping a second preview into the same tester would reuse
    // the first preview's element.

    // The finding. The screen renders `totalPayout` verbatim and then renders
    // the breakdown, and nothing connects the two: no sum, no residual line, no
    // warning. The state the CATALOG has shipped since it was written puts
    // `USD 184.50` over lines totalling `USD 28.00`, and the surface is silent.
    testWidgets('the headline does not reconcile with the lines below it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPaid);

      expect(find.text('USD 184.50'), findsOneWidget);
      expect(find.text('USD 16.00'), findsOneWidget);
      expect(find.text('USD 12.00'), findsOneWidget);
      // 16.00 + 12.00 = 28.00, which appears nowhere: the screen never sums the
      // breakdown and never shows what the remaining 156.50 is for.
      expect(find.text('USD 28.00'), findsNothing);
      expect(find.textContaining('156.50'), findsNothing);
    });

    // `SettlementDeliveryLine` carries `deliveryId` and `fare`; `lib/` renders
    // neither, here or anywhere else. A Jeeber disputing a line can read its
    // date, tier, platform fee and net, but not which delivery it was, nor the
    // fare the fee was taken from.
    testWidgets('a breakdown line names neither its delivery nor its fare', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPaid);

      // On screen: date, tier, net, fee.
      expect(find.text('2026-06-24'), findsOneWidget);
      expect(find.text('Express'), findsOneWidget);
      expect(find.text('Platform fee: USD 4.00'), findsOneWidget);
      // Not on screen: the delivery id, and the fare the 4.00 was taken from.
      expect(find.textContaining('REQ-1042'), findsNothing);
      expect(find.textContaining('REQ-1038'), findsNothing);
      expect(find.text('USD 20.00'), findsNothing);
      expect(find.text('USD 15.00'), findsNothing);
    });

    // D41/D44 fee-only framing, asserted at the preview layer so a regression
    // shows up in the canvas review as well as in `decision_violations_test`.
    testWidgets('the per-delivery cut is framed as a platform fee', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPending);

      expect(find.text('Platform fee: USD 2.40'), findsOneWidget);
      expect(find.textContaining('Commission'), findsNothing);
      expect(find.text('Total cash kept'), findsOneWidget);
      // The one element that separates this state from the paid one.
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Paid'), findsNothing);
    });

    // The finding. `deliveries: []` still renders the breakdown heading, and
    // then nothing — no empty copy, no CTA. Every other list surface in the app
    // has an empty state; this section is a label over blank surface.
    testWidgets('an empty breakdown renders a heading over nothing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenNoDeliveries);

      // The heading is there...
      expect(find.text('Delivery Breakdown'), findsOneWidget);
      // ...and not one line under it, nor any copy standing in for them.
      expect(find.textContaining('Platform fee'), findsNothing);
      expect(find.textContaining('no deliveries'), findsNothing);
      expect(find.textContaining('No deliveries'), findsNothing);
      // The whole surface is the app bar, the summary card and the heading.
      expect(find.text('Jul 6 – Jul 12'), findsOneWidget);
      expect(find.text('USD 0.00'), findsOneWidget);
    });

    // The finding. `weekLabel` is the app-bar title AND the field
    // `SettlementStatement.fromJson` defaults to `''`. A payload that spells the
    // period key a third way opens the statement under a blank title bar, with
    // nothing on screen naming the period being settled.
    testWidgets('an unlabelled period opens under a blank title bar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPartialPayload);

      // The payout parsed fine — this is not a failed load, it is a labelled
      // screen with no label.
      expect(find.text('USD 42.75'), findsOneWidget);
      // The `period` key the parser does not read.
      expect(find.text('Jul 13 – Jul 19'), findsNothing);
      // The title is an empty string, not a fallback.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('')),
        findsOneWidget,
      );
    });

    // The `Navigator` the preview host adds is not decoration: without it the
    // app bar's default `Navigator.of(context).maybePop()` throws on tap. With
    // it the back button resolves and does nothing, which is what the app does
    // too — this route is reached by a stack-replacing navigation and has
    // nothing to pop (ORPHAN JEBV4-227).
    testWidgets('the back affordance resolves and is inert', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPaid);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Still on the statement.
      expect(find.text('USD 184.50'), findsOneWidget);
    });
  });

  // The layout defects, and the reason this group resizes the surface: the
  // `flutter_test` default is 800x600, wider than any phone, and neither row on
  // this screen is constrained. `_SummaryCard`'s header `Row` has no flexible
  // child at all; `_DeliveryLineRow` makes only its LEFT column `Expanded`, so
  // the amounts column is laid out first against an unbounded main-axis
  // constraint and can neither wrap nor ellipsize.
  group('SettlementDetailScreen previews · at the declared canvas width', () {
    Future<void> pumpAt(
      WidgetTester tester,
      Widget Function() preview,
      Size box, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(box);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    // The control for the AR test below: at 390 pt the English header fits, so
    // an overflow there is a fact about the copy, not about this setup.
    testWidgets('the summary header survives EN at 390 pt', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, settlementDetailScreenPaid, _phoneBox);

      expect(find.text('Total cash kept'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // KNOWN DEFECT, and the sharpest form of it: AR does NOT survive at 390 pt.
    // The EN test directly above is the control — the same preview, the same
    // box, no overflow — so this is a property of the localized copy meeting a
    // rigid `Row`, not of the surface size or the harness.
    //
    // "إجمالي النقد المحتفظ به" is 5 characters longer than "Total cash kept",
    // and `_SummaryCard`'s header has no flexible child to absorb it: the label
    // and the status chip are both rigid under `spaceBetween`, so the row runs
    // 37 px past the card on a MAINSTREAM phone width at 100% text. This is not
    // an accessibility-ceiling edge case — it is the default Arabic rendering.
    //
    // If this starts coming back empty the header has been given an `Expanded`
    // or an ellipsis: delete this test and the second bullet in the JEEB
    // PREVIEWS section of the screen.
    testWidgets('KNOWN DEFECT: the summary header overflows in AR at 390 pt', (
      WidgetTester tester,
    ) async {
      final List<String> overflows = await _overflowsAt(
        tester,
        settlementDetailScreenPaid,
        _phoneBox,
        locale: const Locale('ar'),
      );

      // The label is in the tree — it is painted past the card edge, not
      // dropped, so nothing on screen tells the user it was clipped.
      expect(find.text('إجمالي النقد المحتفظ به'), findsOneWidget);
      expect(
        overflows,
        isNotEmpty,
        reason: 'the Arabic payout label plus the status chip exceed the card '
            'width at 390 pt, and neither child can flex',
      );
    });

    testWidgets('the LBP breakdown renders at 390 pt', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, settlementDetailScreenLbp, _phoneBox);

      expect(find.text('LBP 2025000.00'), findsOneWidget);
      expect(find.text('Platform fee: LBP 225000.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the long week label renders in the app bar at 390 pt', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, settlementDetailScreenLbp, _phoneBox);

      expect(
        find.text(
          'Jul 27 – Aug 2 (adjusted, includes Jun 29 – Jul 5 carry-over)',
        ),
        findsOneWidget,
      );
    });
  });
}
