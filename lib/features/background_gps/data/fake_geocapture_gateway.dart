import 'dart:async';

import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';

/// Test double for [GeocaptureGateway].
///
/// `permissionScript` is consumed left-to-right per
/// `currentPermission()` / `requestAlwaysPermission()` call — once
/// exhausted, the last value sticks. `emit` pushes a sample through the
/// broadcast stream so the cubit's listener fires synchronously.
class FakeGeocaptureGateway implements GeocaptureGateway {
  FakeGeocaptureGateway({
    List<LocationPermission>? permissionScript,
    LocationPermission initialPermission = LocationPermission.always,
  })  : _permissionScript = List<LocationPermission>.from(
          permissionScript ?? <LocationPermission>[],
        ),
        _lastPermission = initialPermission;

  final List<LocationPermission> _permissionScript;
  LocationPermission _lastPermission;
  final StreamController<GpsSample> _controller =
      StreamController<GpsSample>.broadcast();
  bool stopped = false;

  /// Number of times the cubit asked for the system permission prompt.
  int requestCount = 0;

  @override
  Future<LocationPermission> currentPermission() async {
    if (_permissionScript.isEmpty) return _lastPermission;
    final next = _permissionScript.removeAt(0);
    _lastPermission = next;
    return next;
  }

  @override
  Future<LocationPermission> requestAlwaysPermission() async {
    requestCount += 1;
    if (_permissionScript.isEmpty) return _lastPermission;
    final next = _permissionScript.removeAt(0);
    _lastPermission = next;
    return next;
  }

  @override
  Stream<GpsSample> samples() => _controller.stream;

  @override
  Future<void> stop() async {
    stopped = true;
  }

  /// Pushes a sample through and yields so the cubit's listener runs
  /// before the test continues. Tests should `await` this.
  Future<void> emit(GpsSample sample) async {
    _controller.add(sample);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> emitError(Object error) async {
    _controller.addError(error);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
