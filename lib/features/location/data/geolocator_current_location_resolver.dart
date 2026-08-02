import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../../background_gps/domain/location_permission.dart';
import '../domain/current_location_resolver.dart';

class GeolocatorCurrentLocationResolver implements CurrentLocationResolver {
  GeolocatorCurrentLocationResolver({GeolocatorGeocaptureGateway? gateway})
      : _gateway = gateway ?? GeolocatorGeocaptureGateway();

  final GeolocatorGeocaptureGateway _gateway;

  @override
  Future<CurrentLocationResult> resolve() async {
    try {
      if (!await _gateway.isLocationServiceEnabled()) {
        return const CurrentLocationResult.serviceDisabled();
      }
      var permission = await _gateway.currentPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.notDetermined) {
        permission = await _gateway.requestAlwaysPermission();
      }
      if (permission == LocationPermission.denied) {
        return const CurrentLocationResult.permissionDenied();
      }
      final fix = await _gateway.currentFix();
      return CurrentLocationResult.resolved(fix.latitude, fix.longitude);
    } catch (_) {
      return const CurrentLocationResult.failed();
    }
  }

  @override
  Future<void> openLocationSettings() => _gateway.openLocationSettings();

  @override
  Future<void> openAppSettings() => _gateway.openAppSettings();
}
