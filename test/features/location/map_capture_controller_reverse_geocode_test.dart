import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/domain/reverse_geocoder.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';

void main() {
  test(
    'an older idle lookup cannot overwrite the newer settled point',
    () async {
      final geocoder = _QueuedReverseGeocoder();
      final controller = MapCaptureController(
        initial: const LocationPoint(latitude: 33.88, longitude: 35.50),
        reverseGeocoder: geocoder,
      );
      addTearDown(controller.dispose);

      controller.markReady();
      controller.updateCenter(
        const LocationPoint(latitude: 33.91, longitude: 35.52),
      );
      controller.markReady();

      geocoder.lookups[1].complete('New settled address');
      await Future<void>.delayed(Duration.zero);
      expect(controller.center.address, 'New settled address');

      geocoder.lookups[0].complete('Old address');
      await Future<void>.delayed(Duration.zero);

      expect(controller.center.address, 'New settled address');
      expect(controller.center.latitude, 33.91);
      expect(controller.center.longitude, 35.52);
    },
  );
}

class _QueuedReverseGeocoder implements ReverseGeocoder {
  final List<Completer<String?>> lookups = <Completer<String?>>[];

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    final lookup = Completer<String?>();
    lookups.add(lookup);
    return lookup.future;
  }
}
