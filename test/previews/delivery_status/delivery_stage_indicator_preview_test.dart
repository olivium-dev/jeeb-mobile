// Render tests for the DeliveryStageIndicator previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// `expectedText` pins a TIMESTAMP per state, never a stage label. The four
// labels ("Matched", "Picked up", "In transit", "Delivered") come from the ARB
// and are identical in all six states — worse, each one renders TWICE per card
// (once in the stepper's label row, once in the milestone row below it). A
// suite that pinned labels would pass with every preview handed the same
// snapshot, which is exactly the failure this project has already shipped once.
// The captions are the only per-state text on the card, so they are what pins
// each state to itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_stage_indicator.dart';

import '../preview_test_harness.dart';

/// The pulsing halo painted only under the active milestone. Private to the
/// widget (`_StageDotState.activeKey`), but [Key] equality is by value.
const Key _activeDotKey = Key('delivery-status-active-dot');

/// [DeliveryStageIndicator.listKey], restated so the test does not need to
/// import the widget just for a key.
const Key _listKey = Key('delivery-status-stage-list');

Key _rowKey(DeliveryStage stage) => Key('delivery-stage-row-${stage.name}');

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryStageIndicator',
    const <String, Widget Function()>{
      'Matched · active': deliveryStageIndicatorMatched,
      'In transit · active': deliveryStageIndicatorInTransit,
      'Delivered · completed': deliveryStageIndicatorDelivered,
      'Cancelled after pickup': deliveryStageIndicatorCancelled,
      'Timestamps not backfilled': deliveryStageIndicatorMissingTimestamps,
      'Across midnight': deliveryStageIndicatorAcrossMidnight,
    },
    expectedText: const <String, String>{
      'Matched · active': 'at 10:00',
      'In transit · active': 'at 10:21',
      'Delivered · completed': 'at 11:04',
      'Cancelled after pickup': 'at 09:31',
      'Timestamps not backfilled': 'at 00:04',
      'Across midnight': 'at 23:47',
    },
  );

  group('DeliveryStageIndicator preview specifics', () {
    testWidgets('all four milestone rows render in every state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStageIndicatorMatched);

      for (final DeliveryStage stage in DeliveryStage.values) {
        expect(
          find.byKey(_rowKey(stage)),
          findsOneWidget,
          reason: '${stage.name} row must render even before it is reached',
        );
      }
      // Three unreached rows, one reached — the pending caption is the only
      // thing distinguishing them textually.
      expect(find.text('Waiting…'), findsNWidgets(3));
    });

    testWidgets('exactly one dot pulses while the delivery is active', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStageIndicatorInTransit);

      expect(find.byKey(_activeDotKey), findsOneWidget);
    });

    testWidgets('a completed delivery stops pulsing entirely', (
      WidgetTester tester,
    ) async {
      // `_isActive` is gated on `lifecycle == active`, so a terminal delivery
      // must show no halo at all. A finished delivery that keeps pulsing at the
      // user would mean the didUpdateWidget stop/reset path had broken.
      await pumpPreview(tester, deliveryStageIndicatorDelivered);

      expect(find.byKey(_activeDotKey), findsNothing);
    });

    testWidgets('cancellation erases the dots but keeps the timestamps', (
      WidgetTester tester,
    ) async {
      // The card ends up asserting both "this never happened" (every dot
      // unreached, stepper emptied) and "this happened at 09:31" at once. Pin
      // it: this is the state the preview exists to argue about, and a future
      // fix should break this test loudly.
      await pumpPreview(tester, deliveryStageIndicatorCancelled);

      expect(find.byKey(_activeDotKey), findsNothing);
      expect(find.text('at 09:12'), findsOneWidget);
      expect(find.text('at 09:31'), findsOneWidget);
      // …and no word anywhere says "cancelled". The ARB has the key
      // (`deliveryStageCancelled`); this widget never reads it.
      expect(find.text('Cancelled'), findsNothing);
    });

    testWidgets('an unbackfilled milestone reads as done AND waiting', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStageIndicatorMissingTimestamps);

      // Delivered, so all four rows are "reached" by stage ordering, but three
      // have no timestamp and fall back to the pending caption.
      expect(find.text('Waiting…'), findsNWidgets(3));
      expect(find.text('at 00:04'), findsOneWidget);
    });

    testWidgets('midnight rollover renders as a backwards list', (
      WidgetTester tester,
    ) async {
      // `DateFormat.Hm` is time-of-day only: no date, no day marker. Four
      // milestones in correct order read 23:47 → 23:58 → 00:12 → 00:35.
      await pumpPreview(tester, deliveryStageIndicatorAcrossMidnight);

      for (final String time in <String>[
        'at 23:47',
        'at 23:58',
        'at 00:12',
        'at 00:35',
      ]) {
        expect(find.text(time), findsOneWidget);
      }
    });

    testWidgets('each stage label renders twice — stepper + milestone row', (
      WidgetTester tester,
    ) async {
      // Documents why `expectedText` above pins timestamps rather than labels:
      // `find.text('In transit')` can never be `findsOneWidget` here.
      await pumpPreview(tester, deliveryStageIndicatorInTransit);

      for (final String label in <String>[
        'Matched',
        'Picked up',
        'In transit',
        'Delivered',
      ]) {
        expect(find.text(label), findsNWidgets(2), reason: label);
      }
    });

    testWidgets('Arabic captions keep Latin digits', (
      WidgetTester tester,
    ) async {
      // `_formatTime`'s comment claims the Arabic locale falls back to Latin
      // digits. It is right, but only by accident of packaging: intl's own
      // `ar` symbols carry an Arabic-Indic ZERODIGIT, while the trimmed `ar`
      // symbols `flutter_localizations` registers (which is what wins here,
      // via GlobalMaterialLocalizations) do not. Anyone who later calls
      // `initializeDateFormatting()` from `package:intl/date_symbol_data_local`
      // BEFORE the delegate loads would flip these captions to ١٠:٢١. Pinned
      // so that flip cannot happen silently.
      await pumpPreview(
        tester,
        deliveryStageIndicatorInTransit,
        locale: const Locale('ar'),
      );

      expect(find.text('الساعة 10:21'), findsOneWidget);
      expect(find.text('at 10:21'), findsNothing);
    });

    testWidgets('the whole indicator fits the 390x300 box it declares', (
      WidgetTester tester,
    ) async {
      // The `size:` constants in the preview file quote measured heights. This
      // re-measures the 1x block so an edit that adds a fifth milestone row
      // fails in CI instead of silently clipping in the canvas.
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, deliveryStageIndicatorAcrossMidnight);
      // The stepper label Row overflows at this width under the test's
      // fallback font — that is the subject of the next test, not this one.
      tester.takeException();

      final Size rendered = tester.getSize(find.byKey(_listKey));
      expect(rendered.width, 350, reason: '390 dp phone minus 2x Spacing.large');
      // Measured 350x280 in EN and in AR, in all six states — the four rows
      // always render and every caption is one line, so height does not vary
      // with the snapshot at 1x.
      expect(
        rendered.height,
        lessThanOrEqualTo(300),
        reason: 'must fit the 390x300 box the previews declare',
      );
    });

    testWidgets('the stepper label Row has no flex and overflows when narrow', (
      WidgetTester tester,
    ) async {
      // `OMDSLabeledStepperProgress` lays its four labels out in
      // `Row(mainAxisAlignment: spaceBetween)` with no Expanded, no Flexible
      // and no maxLines, so the labels' natural width decides everything. On a
      // 390 dp phone the track is 350 dp; the four labels measure 434 dp under
      // the test's fallback font, hence 84 dp of yellow-and-black stripe.
      //
      // The bundled Inter is roughly half that wide, so this does NOT overflow
      // on a real 1x phone — it overflows at the 200% rendering, which is the
      // same arithmetic. This test pins the *shape* of the defect (a flex-less
      // Row) rather than a font-specific number; when OMDS wraps those labels
      // in Flexible, it fails and this preview's doc comment should be updated.
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, deliveryStageIndicatorInTransit);

      final Object? error = tester.takeException();
      expect(error, isFlutterError);
      expect(
        error.toString(),
        contains('overflowed'),
        reason: 'the four stepper labels do not fit 350 dp and cannot shrink',
      );
    });
  });
}
