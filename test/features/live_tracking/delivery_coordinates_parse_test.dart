// D-V2: `GET /v1/deliveries/{id}` always carried the route endpoints; the
// parser dropped them, so the map opened on Beirut for an Almere delivery.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';

void main() {
  group('DeliveryTrackingInfo.fromDeliveryJson — route endpoints', () {
    test('parses the live gateway pickup/dropoff coordinates', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', const {
        'id': 'd-1',
        'status': 'Ordered',
        'pickupLocation': {'lat': 52.3994975, 'lng': 5.2751518},
        'dropoffLocation': {'lat': 52.4002, 'lng': 5.2744},
      });

      expect(info.pickupPoint?.lat, closeTo(52.3994975, 1e-9));
      expect(info.pickupPoint?.lng, closeTo(5.2751518, 1e-9));
      expect(info.dropoffPoint?.lat, closeTo(52.4002, 1e-9));
      expect(info.dropoffPoint?.lng, closeTo(5.2744, 1e-9));
    });

    test('accepts the snake_case spelling', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', const {
        'status': 'Ordered',
        'pickup_location': {'lat': 1.5, 'lng': 2.5},
        'dropoff_location': {'latitude': 3.5, 'longitude': 4.5},
      });

      expect(info.pickupPoint, const GpsPoint(lat: 1.5, lng: 2.5));
      expect(info.dropoffPoint, const GpsPoint(lat: 3.5, lng: 4.5));
    });

    test('null island and missing keys stay null, never a 0,0 pin', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', const {
        'status': 'Ordered',
        'pickupLocation': {'lat': 0, 'lng': 0},
      });

      expect(info.pickupPoint, isNull);
      expect(info.dropoffPoint, isNull);
    });

    test('survives the live-position merge', () {
      final info = DeliveryTrackingInfo.fromDeliveryJson('d-1', const {
        'status': 'Ordered',
        'dropoffLocation': {'lat': 52.4002, 'lng': 5.2744},
      }).withLivePosition(
        jeeberPosition: const GpsPoint(lat: 52.39, lng: 5.26),
      );

      expect(info.dropoffPoint, const GpsPoint(lat: 52.4002, lng: 5.2744));
    });
  });
}
