import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;

import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart' as domain;

/// Production [GeocaptureGateway] shim over the `geolocator` plugin
/// (T-MOB-012 / T-MOB-017). It is the device-backed drop-in behind the same
/// port [FakeGeocaptureGateway] implements, so the cubit, picker, and tests
/// never import `geolocator` directly — `dart analyze` stays green without a
/// Maps key and the Fakes remain the unit-test seam.
///
/// Permission mapping (`geolocator` → domain):
///   * denied             → [domain.LocationPermission.denied]
///   * deniedForever      → [domain.LocationPermission.deniedForever]
///   * whileInUse         → [domain.LocationPermission.whileInUse]
///   * always             → [domain.LocationPermission.always]
///   * unableToDetermine  → [domain.LocationPermission.notDetermined]
///
/// ## Why the two request methods are the SAME geolocator call
///
/// `geolocator` exposes exactly one entry point — `Geolocator.requestPermission()`
/// — and decides INTERNALLY which Android permissions go into the request array
/// by reading the CURRENT status first (`geolocator_android-5.0.3`
/// `PermissionManager.java:104-111`):
///
/// ```java
/// if (SDK_INT >= Q && hasPermissionInManifest(ACCESS_BACKGROUND_LOCATION)) {
///   if (checkPermissionStatus(activity) == whileInUse) {
///     permissionsToRequest.add(ACCESS_BACKGROUND_LOCATION);
///   }
/// }
/// ```
///
/// So the SEQUENCE is what makes the flow incremental, not the arguments:
///   * called while the status is `denied`/`notDetermined` → requests
///     FINE + COARSE only (the foreground step), and
///   * called again once the status is `whileInUse` → adds
///     `ACCESS_BACKGROUND_LOCATION` (the escalation step).
///
/// [requestWhileInUsePermission] and [requestAlwaysPermission] are therefore
/// two named positions in that sequence rather than two different plugin calls.
/// Keeping them distinct on the port is deliberate: it is what stops a future
/// caller from "simplifying" the cubit back into a single request, which is the
/// exact shape Android 11+ ignores outright.
///
/// **`ACCESS_BACKGROUND_LOCATION` must stay declared in `AndroidManifest.xml`**
/// — both branches above are gated on `hasPermissionInManifest`, so without it
/// `checkPermission()` can never return `always` (`PermissionManager.java:71-76`)
/// and the whole upload pipeline parks silently.
///
/// The stream is wrapped as a broadcast so the cubit can `listen` more than once
/// per lifecycle (the port contract requires idempotent listens).
class GeolocatorGeocaptureGateway implements GeocaptureGateway {
  GeolocatorGeocaptureGateway({
    geo.LocationSettings? locationSettings,
  }) : _locationSettings = locationSettings ??
            const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
              distanceFilter: 10,
            );

  final geo.LocationSettings _locationSettings;
  StreamSubscription<geo.Position>? _subscription;
  StreamController<GpsSample>? _controller;

  @override
  Future<domain.LocationPermission> currentPermission() async {
    final permission = await geo.Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<domain.LocationPermission> requestWhileInUsePermission() async {
    final permission = await geo.Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<domain.LocationPermission> requestAlwaysPermission() async {
    final permission = await geo.Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Stream<GpsSample> samples() {
    final existing = _controller;
    if (existing != null && !existing.isClosed) return existing.stream;
    // close_sinks can't trace the close across methods — the controller is
    // closed in stop() (and on the last listener cancel). Long-lived by design.
    // ignore: close_sinks
    final controller = StreamController<GpsSample>.broadcast(
      onCancel: () => _subscription?.cancel(),
    );
    _controller = controller;
    _subscription = geo.Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (position) => controller.add(_toSample(position)),
      onError: controller.addError,
    );
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
  }

  /// One-shot current fix for the "centre on my location" affordance. Not on
  /// the [GeocaptureGateway] port (that streams); the map picker calls it
  /// directly via the concrete adapter the DI container provides.
  Future<GpsSample> currentFix() async {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: _locationSettings,
    );
    return _toSample(position);
  }

  /// Whether the device's location services (the OS-level GPS toggle) are on.
  /// A `false` here is distinct from a denied app permission: the recovery UI
  /// (JEBV4-176) routes it to the "turn on location services" affordance
  /// ([openLocationSettings]) rather than the app-permission one. Not on the
  /// streaming [GeocaptureGateway] port — the one-shot current-location
  /// resolver calls it directly via this concrete adapter.
  Future<bool> isLocationServiceEnabled() =>
      geo.Geolocator.isLocationServiceEnabled();

  /// Opens the OS location-services settings page (device GPS toggle). Used by
  /// the GPS-recovery UI's "open settings" CTA when location services are off.
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  /// Opens this app's OS settings page so the user can grant the location
  /// permission after a permanent denial. Used by the GPS-recovery UI's
  /// "open settings" CTA when the app permission is denied, and by the
  /// Active Delivery screen's background-location banner (Android 11+ routes
  /// the "Allow all the time" upgrade through this page).
  @override
  Future<bool> openAppSettings() => geo.Geolocator.openAppSettings();

  GpsSample _toSample(geo.Position position) {
    final heading = position.heading;
    return GpsSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMps: position.speed,
      headingDegrees: heading.isNaN ? 0 : heading,
      capturedAt: position.timestamp,
    );
  }

  domain.LocationPermission _mapPermission(geo.LocationPermission permission) {
    switch (permission) {
      case geo.LocationPermission.denied:
        return domain.LocationPermission.denied;
      // Kept DISTINCT from `denied` (it used to collapse into it): the OS will
      // not prompt again from here, so re-requesting is a silent no-op and the
      // only honest affordance is the settings page.
      case geo.LocationPermission.deniedForever:
        return domain.LocationPermission.deniedForever;
      case geo.LocationPermission.whileInUse:
        return domain.LocationPermission.whileInUse;
      case geo.LocationPermission.always:
        return domain.LocationPermission.always;
      case geo.LocationPermission.unableToDetermine:
        return domain.LocationPermission.notDetermined;
    }
  }
}
