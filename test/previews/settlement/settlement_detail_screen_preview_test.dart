// Render tests for the SettlementDetailScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settlement/presentation/settlement_detail_screen.dart';

import '../preview_test_harness.dart';

/// The box `LBP · compact 320` declares
/// (`_settlementDetailScreenCompactBox`). The harness pumps at the
const Size _compactBox = Size(320, 568);

/// The box the other five previews declare
/// (`_settlementDetailScreenPhoneBox`).
const Size _phoneBox = Size(390, 844);

/// Pumps [preview] at [box] and returns every overflow that frame reported.
/// Intercepting `FlutterError.onError` is what makes a MULTI-overflow state
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
      'Paid · two deliveries': 'USD 184.50',
      'Pending · one delivery': 'USD 96.00',
      // This one PINS THE TITLE on purpose: the payout is `USD 0.00`, which the
      'Empty · no delivery lines': 'Jul 6 – Jul 12',
      // Eight digits, hand-formatted with two forced decimals and no grouping
      'LBP · six lines': 'LBP 12555000.00',
      'Partial payload · blank title': 'USD 42.75',
    },
  );

  // The narrow-surface twin of `LBP · six lines`. Same statement, so the shared
  group('SettlementDetailScreen previews · LBP · compact 320', () {
    // KNOWN DEFECT, both locales. At 320 pt the screen reports TWO overflows per
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
      await _overflowsAt(
        tester,
        settlementDetailScreenLbpCompact,
        _compactBox,
      );

      expect(find.text('LBP 12555000.00'), findsOneWidget);
      // The amounts column is never TRUNCATED — it is the non-flexible child,
      expect(find.text('LBP 2025000.00'), findsOneWidget);
      expect(find.text('Platform fee: LBP 225000.00'), findsOneWidget);
    });
  });

  group('SettlementDetailScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree

    // The finding. The screen renders `totalPayout` verbatim and then renders
    testWidgets('the headline does not reconcile with the lines below it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPaid);

      expect(find.text('USD 184.50'), findsOneWidget);
      expect(find.text('USD 16.00'), findsOneWidget);
      expect(find.text('USD 12.00'), findsOneWidget);
      // 16.00 + 12.00 = 28.00, which appears nowhere: the screen never sums the
      expect(find.text('USD 28.00'), findsNothing);
      expect(find.textContaining('156.50'), findsNothing);
    });

    // `SettlementDeliveryLine` carries `deliveryId` and `fare`; `lib/` renders
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
    testWidgets('an unlabelled period opens under a blank title bar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, settlementDetailScreenPartialPayload);

      // The payout parsed fine — this is not a failed load, it is a labelled
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
    testWidgets('the summary header survives EN at 390 pt', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, settlementDetailScreenPaid, _phoneBox);

      expect(find.text('Total cash kept'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // KNOWN DEFECT, and the sharpest form of it: AR does NOT survive at 390 pt.
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
