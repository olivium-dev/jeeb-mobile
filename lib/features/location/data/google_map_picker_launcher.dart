import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../presentation/capture_location_screen.dart';
import '../presentation/widgets/capture_picker_sheet.dart';
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
    // Only a camera that really settled proves the platform view rendered; a
    // map that never initialised must not hand the seed back as a choice.
    var cameraLive = false;
    return Navigator.of(_context).push<LocationPoint>(
      MaterialPageRoute<LocationPoint>(
        fullscreenDialog: true,
        builder: (routeContext) => CaptureLocationScreen(
          // The sheet reads the same controller the map writes, so the pinned
          // coordinate the CTA returns is the one the customer can see.
          controller: controller,
          mapBuilder: (mapContext) => GoogleMapCaptureView(
            controller: controller,
            gateway: _gateway,
            onCameraSettled: () => cameraLive = true,
            // Lift the recentre control clear of the docked picker sheet —
            // the map runs full-bleed underneath it now.
            bottomInset: CapturePickerSheet.dockedClearance + Spacing.large,
          ),
          onPinned: () => Navigator.of(routeContext).pop<LocationPoint>(
            cameraLive ? controller.center : null,
          ),
        ),
      ),
    );
  }
}
