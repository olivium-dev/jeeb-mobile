import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../../background_gps/domain/location_permission.dart';
import '../domain/current_location_resolver.dart';

/// Production [CurrentLocationResolver] over [GeolocatorGeocaptureGateway]
/// (JEBV4-176). Mirrors the go-online one-shot-fix pattern already used for the
/// jeeber availability toggle (see `injection_container.dart`): ensure location
/// services are on, ensure a foreground grant (prompt once when
/// denied/undetermined), then take a single fix — degrading to a typed
/// [CurrentLocationOutcome] instead of ever fabricating a coordinate.
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
      // A platform channel error / timeout is a genuine acquisition failure —
      // surfaced as a retryable state, never a silent fake fix.
      return const CurrentLocationResult.failed();
    }
  }

  @override
  Future<void> openLocationSettings() => _gateway.openLocationSettings();

  @override
  Future<void> openAppSettings() => _gateway.openAppSettings();
}
