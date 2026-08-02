import 'gps_sample.dart';
import 'location_permission.dart';

abstract class GeocaptureGateway {
  Future<LocationPermission> currentPermission();

  Future<LocationPermission> requestWhileInUsePermission();

  Future<LocationPermission> requestAlwaysPermission();

  Future<bool> openAppSettings();

  Stream<GpsSample> samples();

  Future<void> stop();
}
