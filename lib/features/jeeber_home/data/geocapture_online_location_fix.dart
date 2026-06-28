import '../../background_gps/data/geolocator_geocapture_gateway.dart';
import '../../background_gps/domain/location_permission.dart';
import '../domain/online_location_fix.dart';

/// Production [OnlineLocationFix] over the existing geolocator-backed
/// [GeolocatorGeocaptureGateway] (reuse — the same adapter the map picker's
/// "centre on me" button uses). It prompts for location permission when needed,
/// then asks for ONE current fix.
///
/// Permission policy: a foreground one-shot fix only needs
/// [LocationPermission.whileInUse]; we therefore accept `whileInUse` and
/// `always`, and only re-prompt from `denied`/`notDetermined`. A still-denied
/// result (or any plugin error) yields `null` so the decorated action — going
/// online, creating a request — proceeds without coordinates rather than
/// failing. On the proof devices (real GPS / simctl-set location) permission is
/// granted, so a real fix flows through.
class GeocaptureOnlineLocationFix implements OnlineLocationFix {
  const GeocaptureOnlineLocationFix(this._gateway);

  final GeolocatorGeocaptureGateway _gateway;

  @override
  Future<OnlineCoordinates?> resolve() async {
    try {
      final granted = await _ensurePermission();
      if (!granted) return null;
      final fix = await _gateway.currentFix();
      return OnlineCoordinates(
        latitude: fix.latitude,
        longitude: fix.longitude,
      );
    } catch (_) {
      // Never let a location failure block going online / creating a request.
      return null;
    }
  }

  Future<bool> _ensurePermission() async {
    var permission = await _gateway.currentPermission();
    if (permission == LocationPermission.notDetermined ||
        permission == LocationPermission.denied) {
      permission = await _gateway.requestAlwaysPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
