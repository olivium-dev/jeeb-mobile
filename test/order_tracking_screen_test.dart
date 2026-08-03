// The tracking screen's quiet fact strip + the map surface wrapper.
//
// redesign-2026-08 (§C tasks 6/7) reshaped both of the widgets this file
// covers, so the probes moved with them — the INTENT of each case is unchanged:
//
//  * the panel used to draw a SECOND (3-step) stepper above a
//    distance/ETA/deadline stack. Both steppers are gone from it: the 4-step
//    `tracking_stepper` at the top of the screen is the only one, and the live
//    ETA moved onto the map's floating pill (`tracking_eta_label`). What the
//    panel still owns — and what these tests still pin — is the distance line,
//    the D18 deadline, and the `tracking_progress_stepper` node whose `value`
//    reports the current stage name.
//  * `trackingStepIndex`'s 5-stage → 3-step collapse is a DOMAIN contract and
//    is asserted here unchanged.
//  * the RTL case still proves the strip mirrors; its text probe is now the
//    Arabic distance line, because the deleted stepper owned the old one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';

import 'support/sync_app_localizations.dart';

DeliveryTrackingInfo _info({
  TrackingStage stage = TrackingStage.inTransit,
  String? distanceLabel = '3 km',
  int? etaMinutes = 20,
}) {
  return DeliveryTrackingInfo(
    deliveryId: 'd-1',
    currentStage: stage,
    stageTimestamps: const {},
    distanceLabel: distanceLabel,
    etaMinutes: etaMinutes,
  );
}

void main() {
  testWidgets('panel renders the distance fact from info', (tester) async {
    await tester.pumpWidget(wrapForTest(DeliveryTrackingPanel(info: _info())));
    await tester.pump();

    expect(find.byKey(DeliveryTrackingPanel.rootKey), findsOneWidget);
    expect(find.text('3 km away from you'), findsOneWidget);
  });

  testWidgets('panel draws no second stepper and no ETA line', (tester) async {
    // The ETA belongs to the map pill now, and there is exactly ONE stepper on
    // this screen. Both of these used to render here.
    await tester.pumpWidget(wrapForTest(DeliveryTrackingPanel(info: _info())));
    await tester.pump();

    expect(find.text('Ordered'), findsNothing);
    expect(find.text('Picked'), findsNothing);
    expect(find.text('In transit'), findsNothing);
    expect(find.text('Estimated time: 20 min'), findsNothing);
  });

  testWidgets('panel shows the distance placeholder when no GPS fix yet',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        DeliveryTrackingPanel(
          info: _info(distanceLabel: null, etaMinutes: null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Distance updating…'), findsOneWidget);
  });

  testWidgets(
      'the panel root and the progress-stepper node stay distinct queryable '
      'ids, and the stage node keeps its 3-label value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapForTest(DeliveryTrackingPanel(info: _info(stage: TrackingStage.picked))),
    );
    await tester.pump();

    expect(find.bySemanticsIdentifier('tracking_status_panel'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('tracking_progress_stepper'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('tracking_distance_label'), findsOneWidget);
    // The node's historical contract is the STAGE NAME, not a drawn stepper.
    final node =
        tester.getSemantics(find.bySemanticsIdentifier('tracking_progress_stepper'));
    expect(node.value, 'Picked');
    handle.dispose();
  });

  testWidgets('panel maps the ordered stage to the first stepper step',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        DeliveryTrackingPanel(info: _info(stage: TrackingStage.ordered)),
      ),
    );
    await tester.pump();

    // trackingStepIndex collapses 5 lifecycle stages onto 3 Figma steps.
    expect(_info(stage: TrackingStage.ordered).trackingStepIndex, 0);
    expect(_info(stage: TrackingStage.picked).trackingStepIndex, 1);
    expect(_info(stage: TrackingStage.atDoor).trackingStepIndex, 2);
    expect(_info(stage: TrackingStage.delivered).trackingStepIndex, 2);
  });

  testWidgets('map surface carries its accessibility identifier', (tester) async {
    await tester.pumpWidget(wrapForTest(const TrackingMapSurface()));
    await tester.pump();

    expect(find.byKey(TrackingMapSurface.rootKey), findsOneWidget);
  });

  testWidgets('the map surface is a fixed-height card, not a viewport eater',
      (tester) async {
    // Loose vertical constraints, exactly as the screen's scrolling Column
    // hands it — the point is that the surface CLAIMS 250 rather than
    // expanding to whatever it is given.
    await tester.pumpWidget(
      wrapForTest(
        const Column(children: [TrackingMapSurface()]),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(TrackingMapSurface.rootKey)).height,
      TrackingMapSurface.mapHeight,
    );
  });

  testWidgets('panel renders mirrored under Arabic locale', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        DeliveryTrackingPanel(info: _info()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    final dir = Directionality.of(
      tester.element(find.byKey(DeliveryTrackingPanel.rootKey)),
    );
    expect(dir, TextDirection.rtl);
    // The Arabic distance line — the strip's own copy, not the deleted
    // stepper's first label.
    expect(find.text('يبعد عنك 3 km'), findsOneWidget);
  });
}
