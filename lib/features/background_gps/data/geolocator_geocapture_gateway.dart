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
///   * deniedForever      → [domain.LocationPermission.denied]
///   * whileInUse         → [domain.LocationPermission.whileInUse]
///   * always             → [domain.LocationPermission.always]
///   * unableToDetermine  → [domain.LocationPermission.notDetermined]
///
/// `geolocator` exposes no "background/always" prompt distinct from the OS
/// flow, so [requestAlwaysPermission] calls `Geolocator.requestPermission()`
/// (which raises the system dialog) and maps the granted result. The stream is
/// wrapped as a broadcast so the cubit can `listen` more than once per
/// lifecycle (the port contract requires idempotent listens).
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
  /// "open settings" CTA when the app permission is denied.
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
      case geo.LocationPermission.deniedForever:
        return domain.LocationPermission.denied;
      case geo.LocationPermission.whileInUse:
        return domain.LocationPermission.whileInUse;
      case geo.LocationPermission.always:
        return domain.LocationPermission.always;
      case geo.LocationPermission.unableToDetermine:
        return domain.LocationPermission.notDetermined;
    }
  }
}
