import 'gps_sample.dart';
import 'location_permission.dart';

abstract class GeocaptureGateway {
  /// Whether this gateway can keep capturing after the app is backgrounded
  /// with foreground-only location permission.
  ///
  /// Android can do this when the stream owns a location foreground service
  /// that was started while the app was visible. Other configurations still
  /// need an `always` grant.
  bool get supportsBackgroundTrackingWithWhileInUse;

  Future<LocationPermission> currentPermission();

  Future<LocationPermission> requestWhileInUsePermission();

  Future<LocationPermission> requestAlwaysPermission();

  Future<bool> openAppSettings();

  Stream<GpsSample> samples();

  Future<void> stop();
}
