import 'package:flutter/material.dart';

import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../presentation/capture_location_screen.dart';
import '../presentation/widgets/google_map_capture_view.dart';
import '../presentation/widgets/map_capture_controller.dart';
import 'location_repository.dart';
import 'map_picker_launcher.dart';

class GoogleMapPickerLauncher implements MapPickerLauncher {
  GoogleMapPickerLauncher(
    this._context, {
    GeolocatorGeocaptureGateway? gateway,
  }) : _gateway = gateway ?? GeolocatorGeocaptureGateway();

  final BuildContext _context;
  final GeolocatorGeocaptureGateway _gateway;

  static const _defaultCenter = LocationPoint(
    latitude: 33.8938,
    longitude: 35.5018,
  );

  @override
  Future<LocationPoint?> pickOnMap({LocationPoint? initial}) {
    final controller = MapCaptureController(initial: initial ?? _defaultCenter);
    return Navigator.of(_context).push<LocationPoint>(
      MaterialPageRoute<LocationPoint>(
        fullscreenDialog: true,
        builder: (routeContext) => CaptureLocationScreen(
          mapBuilder: (mapContext) => GoogleMapCaptureView(
            controller: controller,
            gateway: _gateway,
          ),
          onPinned: () =>
              Navigator.of(routeContext).pop<LocationPoint>(controller.center),
        ),
      ),
    );
  }
}
