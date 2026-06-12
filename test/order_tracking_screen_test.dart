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
  testWidgets('panel renders stepper + distance + ETA from info',
      (tester) async {
    await tester.pumpWidget(wrapForTest(DeliveryTrackingPanel(info: _info())));
    await tester.pump();

    expect(find.byKey(DeliveryTrackingPanel.rootKey), findsOneWidget);
    expect(find.text('Ordered'), findsOneWidget);
    expect(find.text('Picked'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);
    expect(find.text('3 km away from you'), findsOneWidget);
    expect(find.text('Estimated time: 20 min'), findsOneWidget);
  });

  testWidgets('panel shows placeholders when no GPS fix yet', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        DeliveryTrackingPanel(
          info: _info(distanceLabel: null, etaMinutes: null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Distance updating…'), findsOneWidget);
    expect(find.text('Estimated time: —'), findsOneWidget);
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
    expect(find.text('تم الطلب'), findsOneWidget);
  });
}
