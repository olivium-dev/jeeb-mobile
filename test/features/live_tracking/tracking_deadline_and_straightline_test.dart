// JEBV4-218 (E23) — Q-061 pilot tracking fidelity DoD:

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_google_map.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  group('JEBV4-218 — locked D18 deadline is displayed', () {
    testWidgets('the tracking panel renders the locked deadline line',
        (tester) async {
      // A fixed, LOCKED absolute deadline (UTC instant).
      final deadline = DateTime.utc(2026, 7, 12, 15, 45);
      final info = DeliveryTrackingInfo(
        deliveryId: 'd-1',
        currentStage: TrackingStage.inTransit,
        stageTimestamps: const {},
        distanceLabel: '2 km',
        etaMinutes: 12,
        deadline: deadline,
      );

      await tester.pumpWidget(wrapForTest(DeliveryTrackingPanel(info: info)));
      await tester.pumpAndSettle();

      // The dedicated deadline node is present (queryable by uiautomator too).
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('tracking_deadline_label'),
        findsOneWidget,
      );
      handle.dispose();

      // The localized "Arrives by <time>" copy renders (time is locale-formatted
      expect(
        find.textContaining('Arrives by'),
        findsOneWidget,
      );
    });

    testWidgets('the deadline line is ABSENT when the row carries no deadline',
        (tester) async {
      const info = DeliveryTrackingInfo(
        deliveryId: 'd-1',
        currentStage: TrackingStage.inTransit,
        stageTimestamps: {},
      );

      await tester.pumpWidget(wrapForTest(const DeliveryTrackingPanel(info: info)));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsIdentifier('tracking_deadline_label'),
        findsNothing,
      );
      handle.dispose();
    });
  });

  group('JEBV4-218 — straight-line route (Q-061 pilot fidelity)', () {
    test('the route polyline is a straight line (geodesic:false)', () {
      const info = DeliveryTrackingInfo(
        deliveryId: 'd-1',
        currentStage: TrackingStage.inTransit,
        stageTimestamps: {},
        polyline: [
          GpsPoint(lat: 33.8938, lng: 35.5018),
          GpsPoint(lat: 33.8869, lng: 35.5131),
        ],
      );
      final line = trackingPolylines(info).single;
      expect(line.geodesic, isFalse);
      expect(line.points, const [
        LatLng(33.8938, 35.5018),
        LatLng(33.8869, 35.5131),
      ]);
    });
  });

  group('JEBV4-218 — deadline parsed off the delivery row', () {
    test('fromDeliveryJson parses the locked deadline (UTC-normalized)', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', {
        'id': 'd-1',
        'status': 'InTransit',
        'deadline': '2026-07-12T15:45:00Z',
      });
      expect(info.deadline, DateTime.utc(2026, 7, 12, 15, 45));
    });

    test('tolerates the snake_case / alias deadline keys', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', {
        'id': 'd-1',
        'status': 'InTransit',
        'delivery_deadline': '2026-07-12T16:00:00Z',
      });
      expect(info.deadline, DateTime.utc(2026, 7, 12, 16, 0));
    });

    test('is null when the row omits any deadline', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', {
        'id': 'd-1',
        'status': 'InTransit',
      });
      expect(info.deadline, isNull);
    });
  });
}
