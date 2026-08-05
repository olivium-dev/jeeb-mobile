import 'dart:async';

import '../domain/geocapture_gateway.dart';
import '../domain/gps_sample.dart';
import '../domain/location_permission.dart';

class FakeGeocaptureGateway implements GeocaptureGateway {
  FakeGeocaptureGateway({
    List<LocationPermission>? permissionScript,
    LocationPermission initialPermission = LocationPermission.always,
    this.settingsOpenResult = true,
    this.supportsBackgroundTrackingWithWhileInUse = false,
  }) : _permissionScript = List<LocationPermission>.from(
         permissionScript ?? <LocationPermission>[],
       ),
       _lastPermission = initialPermission;

  final bool settingsOpenResult;

  @override
  final bool supportsBackgroundTrackingWithWhileInUse;

  final List<LocationPermission> _permissionScript;
  LocationPermission _lastPermission;
  final StreamController<GpsSample> _controller =
      StreamController<GpsSample>.broadcast();

  bool stopped = false;

  int stopCount = 0;

  final List<String> permissionCalls = <String>[];

  int whileInUseRequestCount = 0;
  int alwaysRequestCount = 0;
  int openAppSettingsCount = 0;

  int get requestCount => whileInUseRequestCount + alwaysRequestCount;

  @override
  Future<LocationPermission> currentPermission() async {
    permissionCalls.add('current');
    return _next();
  }

  @override
  Future<LocationPermission> requestWhileInUsePermission() async {
    permissionCalls.add('whileInUse');
    whileInUseRequestCount += 1;
    return _next();
  }

  @override
  Future<LocationPermission> requestAlwaysPermission() async {
    permissionCalls.add('always');
    alwaysRequestCount += 1;
    return _next();
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount += 1;
    return settingsOpenResult;
  }

  LocationPermission _next() {
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
    stopCount += 1;
  }

  /// Pushes sample and yields so listener runs before test continues.
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
