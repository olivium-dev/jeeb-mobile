import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';

void main() {
  group('DeliveryTrackingInfo.fromTrackingJson — public jeeber slice', () {
    test('parses the public matched-jeeber slice when present', () {
      final info = DeliveryTrackingInfo.fromTrackingJson('dlv-golden-001', {
        'deliveryId': 'dlv-golden-001',
        'jeeberId': 'jeeber-kamal-001',
        'jeeber': {
          'displayName': 'Kamal Hajj',
          'vehicleLabel': 'Motorbike',
          'avatarUrl': 'https://cdn.jeeb.app/avatars/jeeber-kamal-001.jpg',
        },
        'status': 'at_door',
        'polyline': [
          [33.8938, 35.5018],
        ],
        'position': {'lat': 33.8938, 'lng': 35.5018},
      });

      expect(info.jeeber, isNotNull);
      expect(info.jeeber!.displayName, 'Kamal Hajj');
      expect(info.jeeber!.vehicleLabel, 'Motorbike');
      expect(
        info.jeeber!.avatarUrl,
        'https://cdn.jeeb.app/avatars/jeeber-kamal-001.jpg',
      );
    });

    test('jeeber is null while still matching (no jeeber object on the wire)',
        () {
      final info = DeliveryTrackingInfo.fromTrackingJson('dlv-1', {
        'deliveryId': 'dlv-1',
        'jeeberId': 'jeeber-kamal-001',
        'status': 'in_transit',
        'polyline': const [],
      });

      expect(info.jeeber, isNull);
    });

    test('NEVER surfaces phone or pre-completion rating, even if the wire '
        'leaks them (blind-reveal / privacy guard)', () {
      // A defensive contract test: the parser must drop phone + rating so a
      // backend that over-shares cannot push them into the in-flight UI.
      final info = DeliveryTrackingInfo.fromTrackingJson('dlv-1', {
        'jeeber': {
          'displayName': 'Kamal Hajj',
          'vehicleLabel': 'Motorbike',
          'avatarUrl': null,
          'phoneE164': '+96170123456',
          'rating': 4.9,
        },
        'status': 'in_transit',
      });

      expect(info.jeeber, isNotNull);
      expect(info.jeeber!.phoneE164, isNull, reason: 'phone is withheld');
      expect(info.jeeber!.rating, isNull,
          reason: 'pre-completion rating is withheld');
      expect(info.jeeber!.avatarUrl, isNull);
    });

    test('treats a jeeber object missing name or vehicle as not-yet-assigned',
        () {
      final missingName = DeliveryTrackingInfo.fromTrackingJson('dlv-1', {
        'jeeber': {'vehicleLabel': 'Motorbike'},
        'status': 'matched',
      });
      final missingVehicle = DeliveryTrackingInfo.fromTrackingJson('dlv-1', {
        'jeeber': {'displayName': 'Kamal Hajj'},
        'status': 'matched',
      });

      expect(missingName.jeeber, isNull);
      expect(missingVehicle.jeeber, isNull);
    });
  });
}
