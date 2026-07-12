import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';

/// Test double for [CurrentLocationResolver] (JEBV4-176). Scripts the GPS
/// outcome so widget/unit tests can drive the "Current Location" option through
/// every recovery state without a platform channel — no real geolocator, no
/// Beirut fallback.
class FakeCurrentLocationResolver implements CurrentLocationResolver {
  FakeCurrentLocationResolver({
    CurrentLocationResult result = const CurrentLocationResult.resolved(
      _defaultLat,
      _defaultLng,
    ),
  }) : _result = result;

  /// A deterministic, NON-Beirut fix (a Hamra point) so assertions can prove
  /// the created request carries the REAL device coordinate, distinct from the
  /// old `33.8886, 35.4955` fallback.
  static const double _defaultLat = 33.8959;
  static const double _defaultLng = 35.4797;

  final CurrentLocationResult _result;

  int resolveCount = 0;
  int openLocationSettingsCount = 0;
  int openAppSettingsCount = 0;

  @override
  Future<CurrentLocationResult> resolve() async {
    resolveCount += 1;
    return _result;
  }

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCount += 1;

  @override
  Future<void> openAppSettings() async => openAppSettingsCount += 1;
}
