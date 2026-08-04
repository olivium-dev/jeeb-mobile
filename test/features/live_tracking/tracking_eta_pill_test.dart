// redesign-2026-08 §C task 6 — the floating ETA pill on the tracking map.
//
// The ETA moved off the panel (where it was one of three stacked text lines)
// onto a white pill anchored to the map's top-START corner.
//
// THE POINT OF THIS FILE is the second case. Maestro
// `.maestro/flows/16-order-tracking.yaml:80` does
// `assertVisible id: "tracking_eta_label"`, and the fixture's ETA cannot be
// guaranteed — a pill that only renders when `etaMinutes != null` would turn a
// missing gateway field into a red e2e run. So the pill renders whenever there
// is a snapshot at all, and an unknown ETA becomes the pending copy rather than
// a missing node. `liveRegion` is asserted because the ETA is the one number on
// this screen that changes under the customer without them acting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_map_surface.dart';

import '../../support/sync_app_localizations.dart';

DeliveryTrackingInfo _info({int? etaMinutes}) => DeliveryTrackingInfo(
      deliveryId: 'd-12',
      currentStage: TrackingStage.inTransit,
      stageTimestamps: const {},
      etaMinutes: etaMinutes,
    );

void main() {
  testWidgets('a known ETA renders the pill with the live minutes',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapForTest(TrackingMapSurface(info: _info(etaMinutes: 20))),
    );
    await tester.pump();

    expect(find.bySemanticsIdentifier('tracking_eta_label'), findsOneWidget);
    expect(find.text('Arriving in 20 min'), findsOneWidget);

    final node =
        tester.getSemantics(find.bySemanticsIdentifier('tracking_eta_label'));
    expect(
      node.flagsCollection.isLiveRegion,
      isTrue,
      reason: 'the ETA changes under the customer without them acting, so a '
          'screen reader must announce it when it does',
    );
    handle.dispose();
  });

  testWidgets('an UNKNOWN ETA still renders the node, with the pending copy',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrapForTest(TrackingMapSurface(info: _info())));
    await tester.pump();

    expect(
      find.bySemanticsIdentifier('tracking_eta_label'),
      findsOneWidget,
      reason: 'the Maestro flow asserts this id is visible and the fixture ETA '
          'is not guaranteed — the node must not depend on the number',
    );
    expect(find.text('ETA pending'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no snapshot at all → no pill (nothing to say yet)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrapForTest(const TrackingMapSurface()));
    await tester.pump();

    expect(find.bySemanticsIdentifier('tracking_eta_label'), findsNothing);
    handle.dispose();
  });

  testWidgets('the pill pins to the START corner under Arabic', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        TrackingMapSurface(info: _info(etaMinutes: 20)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    final pill = find.text('الوصول خلال 20 دقيقة');
    expect(pill, findsOneWidget);

    final map = tester.getRect(find.byKey(TrackingMapSurface.rootKey));
    final pillRect = tester.getRect(pill);
    // START is the RIGHT edge under RTL: the pill's end is nearer the map's
    // right edge than its start is to the left one.
    expect(map.right - pillRect.right, lessThan(pillRect.left - map.left));
  });
}
