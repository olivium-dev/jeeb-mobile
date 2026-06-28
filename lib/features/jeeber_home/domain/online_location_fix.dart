/// One-shot location resolver used by coordinate-bearing flows that are NOT a
/// continuous track — the jeeber GO ONLINE toggle and the client "current
/// location" request-create path.
///
/// WHY THIS EXISTS (SPRINT-003 matching fix): the delivery-service `ListOnline`
/// query filters `last_lat/last_lng IS NOT NULL`, so a jeeber that goes online
/// with null coordinates is dropped from the online roster and can never be
/// matched (`online_total:0`). Likewise the request pickup needs a real point
/// for the 25 km radius. Both surfaces need a single, current fix — not the
/// streaming [GeocaptureGateway] (which spins up the foreground-tracking
/// pipeline). This port is the seam: production wraps the geolocator-backed
/// adapter; tests supply a deterministic fake. Per JEEB-BOUNDARIES §F9 all GPS
/// access stays behind a gateway port — hand-rolled `Geolocator` calls are
/// PR-blocking.
abstract class OnlineLocationFix {
  /// Returns the device's current coordinates, or `null` when a fix cannot be
  /// obtained (permission denied, location services off, plugin error). The
  /// caller MUST treat `null` as "no coordinates this time" and degrade
  /// gracefully — acquiring a fix must never block the action it decorates
  /// (going online, creating a request).
  Future<OnlineCoordinates?> resolve();
}

/// An immutable lat/lng pair returned by [OnlineLocationFix.resolve].
class OnlineCoordinates {
  const OnlineCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
