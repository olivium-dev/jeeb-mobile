import 'package:flutter/material.dart';

import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../presentation/capture_location_screen.dart';
import '../presentation/widgets/google_map_capture_view.dart';
import '../presentation/widgets/map_capture_controller.dart';
import 'location_repository.dart';
import 'map_picker_launcher.dart';

/// Production [MapPickerLauncher] (T-MOB-012). Pushes the [CaptureLocationScreen]
/// as a full-screen modal with a live `GoogleMap` viewport injected as the
/// `mapBuilder`, and returns the coordinate the user parked under the fixed
/// centre pin (or `null` on cancel) — exactly the port contract.
///
/// It is constructed with the calling [BuildContext] (the location-picker
/// screen owns one) rather than registered as a context-less DI singleton,
/// because pushing a route needs a navigator. The map widget is the sole owner
/// of `google_maps_flutter` types; the launcher itself stays on the domain
/// [LocationPoint], so the cubit and tests never see the plugin.
class GoogleMapPickerLauncher implements MapPickerLauncher {
  GoogleMapPickerLauncher(
    this._context, {
    GeolocatorGeocaptureGateway? gateway,
  }) : _gateway = gateway ?? GeolocatorGeocaptureGateway();

  final BuildContext _context;
  final GeolocatorGeocaptureGateway _gateway;

  /// Beirut downtown — the same canonical default the in-memory repo centres on
  /// so the picker is immediately draggable when no [initial] is supplied.
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
