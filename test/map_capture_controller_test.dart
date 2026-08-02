import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';

void main() {
  // T-MOB-012: the controller is the plugin-free seam between the GoogleMap
  group('MapCaptureController', () {
    test('exposes the initial centre', () {
      final controller = MapCaptureController(
        initial: const LocationPoint(latitude: 33.89, longitude: 35.50),
      );
      expect(controller.center.latitude, 33.89);
      expect(controller.center.longitude, 35.50);
    });

    test('updateCenter moves the centre and notifies listeners', () {
      final controller = MapCaptureController(
        initial: const LocationPoint(latitude: 33.89, longitude: 35.50),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.updateCenter(
        const LocationPoint(latitude: 33.70, longitude: 35.40),
      );

      expect(controller.center,
          const LocationPoint(latitude: 33.70, longitude: 35.40));
      expect(notifications, 1);
    });

    test('updateCenter is a no-op (no notification) when unchanged', () {
      final controller = MapCaptureController(
        initial: const LocationPoint(latitude: 33.89, longitude: 35.50),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.updateCenter(
        const LocationPoint(latitude: 33.89, longitude: 35.50),
      );

      expect(notifications, 0);
    });
  });
}
