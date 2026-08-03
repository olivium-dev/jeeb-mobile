import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_stage_indicator.dart';

import '../preview_test_harness.dart';

/// The pulsing halo painted only under the active milestone. Pr
const Key _activeDotKey = Key('delivery-status-active-dot');

/// [DeliveryStageIndicator.listKey], restated so the test does 
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
      await pumpPreview(tester, deliveryStageIndicatorDelivered);

      expect(find.byKey(_activeDotKey), findsNothing);
    });

    testWidgets('cancellation erases the dots but keeps the timestamps', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStageIndicatorCancelled);

      expect(find.byKey(_activeDotKey), findsNothing);
      expect(find.text('at 09:12'), findsOneWidget);
      expect(find.text('at 09:31'), findsOneWidget);
      expect(find.text('Cancelled'), findsNothing);
    });

    testWidgets('an unbackfilled milestone reads as done AND waiting', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStageIndicatorMissingTimestamps);

      expect(find.text('Waiting…'), findsNWidgets(3));
      expect(find.text('at 00:04'), findsOneWidget);
    });

    testWidgets('midnight rollover renders as a backwards list', (
      WidgetTester tester,
    ) async {
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
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, deliveryStageIndicatorAcrossMidnight);
      tester.takeException();

      final Size rendered = tester.getSize(find.byKey(_listKey));
      expect(rendered.width, 350, reason: '390 dp phone minus 2x Spacing.large');
      expect(
        rendered.height,
        lessThanOrEqualTo(300),
        reason: 'must fit the 390x300 box the previews declare',
      );
    });

    testWidgets('the stepper label Row has no flex and overflows when narrow', (
      WidgetTester tester,
    ) async {
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
