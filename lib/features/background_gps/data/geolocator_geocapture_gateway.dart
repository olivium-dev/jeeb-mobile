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
