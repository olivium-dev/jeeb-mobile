// Render tests for the DeliveryTrackingPanel previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';

import '../preview_test_harness.dart';

/// Re-pumps a preview at the box the canvas gives it, instead of the 800x600
/// default surface.
Future<void> _pumpAtCanvas(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  Size size = const Size(390, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// The label the deadline line must render, formatted the way the widget
/// formats it (`DateFormat.jm(localeTag).format(deadline.toLocal())`) rather
String _deadlineLabel(String localeTag) =>
    DateFormat.jm(localeTag).format(deliveryTrackingPanelLockedDeadline);

/// The panel's own `Column`, not the one `OMDSLabeledStepperProgress` nests
/// inside it. Descendants come back in depth-first order, so the outer one is
Finder _panelColumn() => find.descendant(
      of: find.byKey(DeliveryTrackingPanel.rootKey),
      matching: find.byType(Column),
    );

/// The height the block WANTS at 200% text on a 390pt frame, measured in a box
/// too tall to clip it.
Future<double> _naturalHeightAt200(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await _pumpAtCanvas(
    tester,
    preview,
    textScale: 2.0,
    size: const Size(390, 2000),
  );
  final double height = tester.getSize(_panelColumn().first).height;
  tester.takeException();
  return height;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryTrackingPanel',
    const <String, Widget Function()>{
      'In transit · live fix': deliveryTrackingPanelInTransit,
      'Ordered · awaiting first fix': deliveryTrackingPanelAwaitingFix,
      'Locked deadline (Q-061/D18)': deliveryTrackingPanelDeadlineLine,
      'At the door · 0.0 km': deliveryTrackingPanelAtDoor,
      'Long haul · widest lines': deliveryTrackingPanelLongHaul,
    },
    expectedText: const <String, String>{
      'In transit · live fix': '3 km away from you',
      'Ordered · awaiting first fix': 'Distance updating…',
      'Locked deadline (Q-061/D18)': '2 km away from you',
      'At the door · 0.0 km': '0.0 km away from you',
      'Long haul · widest lines': '128.6 km away from you',
    },
  );

  group('DeliveryTrackingPanel preview specifics', () {
    testWidgets('a missing GPS fix degrades to placeholders, never to "0 km"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryTrackingPanelAwaitingFix);

      expect(find.text('Distance updating…'), findsOneWidget);
      expect(find.text('Estimated time: —'), findsOneWidget);
      // The widget's own doc comment is explicit that a stale zero must not be
      expect(find.textContaining('0 km'), findsNothing);
    });

    testWidgets('a REAL zero is not the unknown state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryTrackingPanelAtDoor);

      // The other half of the null checks: 0.0 km / 0 min are values, and the
      expect(find.text('0.0 km away from you'), findsOneWidget);
      expect(find.text('Estimated time: 0 min'), findsOneWidget);
      expect(find.text('Distance updating…'), findsNothing);
      expect(find.text('Estimated time: —'), findsNothing);
    });

    testWidgets('at the door the stepper still reads the In-transit step', (
      WidgetTester tester,
    ) async {
      // P6/A5: `trackingStepIndex` collapses atDoor (and delivered) onto step 2,
      await pumpPreview(tester, deliveryTrackingPanelAtDoor);
      final OMDSLabeledStepperProgress atDoor =
          tester.widget(find.byType(OMDSLabeledStepperProgress));

      await pumpPreview(tester, deliveryTrackingPanelInTransit);
      final OMDSLabeledStepperProgress inTransit =
          tester.widget(find.byType(OMDSLabeledStepperProgress));

      expect(atDoor.completedSteps, 3);
      expect(atDoor.completedSteps, inTransit.completedSteps);
    });

    testWidgets('the deadline line mounts ONLY when the row carries one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryTrackingPanelDeadlineLine);
      expect(
        find.text('Arrives by ${_deadlineLabel('en')}'),
        findsOneWidget,
      );

      // Q-061 / D18: the line is behind `if (info.deadline != null)`, so a
      await pumpPreview(tester, deliveryTrackingPanelInTransit);
      expect(find.textContaining('Arrives by'), findsNothing);
    });

    testWidgets('every line localizes its frame in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryTrackingPanelDeadlineLine,
        locale: const Locale('ar'),
      );

      expect(find.text('تم الطلب'), findsOneWidget);
      expect(find.text('يبعد عنك 2 km'), findsOneWidget);
      expect(find.text('الوقت المقدّر: 12 دقيقة'), findsOneWidget);
      // The deadline is the ONE string here that does not come from the ARB —
      expect(find.text('يصل بحلول ${_deadlineLabel('ar')}'), findsOneWidget);
      expect(_deadlineLabel('ar'), isNot(_deadlineLabel('en')));
      // ...and it agrees with them on digits: intl's `ar` symbols use Western
      expect(_deadlineLabel('ar'), contains('3:45'));
    });

    testWidgets('the distance UNIT stays English inside the Arabic sentence', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryTrackingPanelLongHaul,
        locale: const Locale('ar'),
      );

      // `distanceLabel` is pre-formatted by the gateway and pasted into the
      expect(find.text('يبعد عنك 128.6 km'), findsOneWidget);
    });

    testWidgets('the stepper labels run past the panel at 200% text', (
      WidgetTester tester,
    ) async {
      // Measured at the canvas width, in a deliberately TALL box so the only
      await _pumpAtCanvas(tester, deliveryTrackingPanelInTransit, textScale: 2.0);

      final double panelRight =
          tester.getBottomRight(find.byType(OMDSLabeledStepperProgress)).dx;
      final double lastLabelRight =
          tester.getBottomRight(find.text('In transit')).dx;

      // `OMDSLabeledStepperProgress` lays its labels out in a bare
      expect(
        lastLabelRight,
        greaterThan(panelRight),
        reason: 'the third stepper label should overflow the panel at 200% '
            'text on a 390pt frame',
      );
      // The overflow is reported by RenderFlex; consume it so the finding is
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('the declared preview boxes are tall enough for 200% text', (
      WidgetTester tester,
    ) async {
      // A preview whose box clips its own content teaches the reviewer nothing
      expect(
        await _naturalHeightAt200(tester, deliveryTrackingPanelInTransit),
        lessThanOrEqualTo(deliveryTrackingPanelBox.height),
      );
      // The four-line state at 200% is the tallest thing this widget can
      expect(
        await _naturalHeightAt200(tester, deliveryTrackingPanelLongHaul),
        lessThanOrEqualTo(deliveryTrackingPanelTallBox.height),
      );
    });
  });
}
