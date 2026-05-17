import 'package:equatable/equatable.dart';

/// A point on the map plus its (optional) resolved address text. Address is
/// nullable because the pin can move faster than reverse-geocoding can respond
/// — the UI distinguishes "address known" from "still resolving" by null.
class LocationPoint extends Equatable {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;

  LocationPoint copyWith({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return LocationPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, address];
}

/// Pickup + dropoff pair persisted for the in-progress delivery request. The
/// summary screen reads this to render the route preview before the request is
/// submitted to jeeb-gateway.
class DeliveryLocations extends Equatable {
  const DeliveryLocations({
    required this.pickup,
    required this.dropoff,
  });

  final LocationPoint pickup;
  final LocationPoint dropoff;

  @override
  List<Object?> get props => [pickup, dropoff];
}

/// What went wrong calling out to the device or the gateway. Mapped to user
/// copy by the cubit so the screen layer doesn't need to know about
/// repository internals.
enum LocationFailureKind {
  gpsPermissionDenied,
  gpsUnavailable,
  geocodingFailed,
  searchFailed,
  saveFailed,
}

class LocationFailure implements Exception {
  const LocationFailure(this.kind);
  final LocationFailureKind kind;
}

/// Repository contract the cubit talks to. A real implementation wires:
///   - GPS via the geocapture-flutter provider,
///   - search + reverse geocoding via jeeb-gateway endpoints,
///   - save via jeeb-gateway request draft state.
///
/// Tests inject a mock; the in-process [InMemoryLocationRepository] below is
/// the default registered in DI until the gateway endpoints land.
abstract class LocationRepository {
  /// Resolves the current device GPS position. Throws [LocationFailure] with
  /// [LocationFailureKind.gpsPermissionDenied] or
  /// [LocationFailureKind.gpsUnavailable] on failure.
  Future<LocationPoint> resolveCurrentGps();

  /// Looks up matching addresses for [query]. Empty query returns an empty
  /// list — the cubit guards against firing the request in that case anyway.
  Future<List<LocationPoint>> searchAddress(String query);

  /// Resolves a human-readable address for [latitude]/[longitude]. Returns
  /// null when the backend has no street-level data for the point.
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  /// Persists the pickup + dropoff pair against the in-progress delivery
  /// request. Returns the canonical pair the gateway echoed back.
  Future<DeliveryLocations> saveDeliveryLocations({
    required LocationPoint pickup,
    required LocationPoint dropoff,
  });

  /// Hands back the last saved pair on cold-load. Returns null when nothing
  /// has been saved for the current draft yet.
  Future<DeliveryLocations?> loadSavedLocations();
}

/// Default in-memory implementation used by DI until the gateway endpoints
/// land. Backs all four operations against a fixed Beirut catalogue so the
/// rest of the request-creation flow can integrate end-to-end without a
/// network.
class InMemoryLocationRepository implements LocationRepository {
  InMemoryLocationRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DeliveryLocations? _saved;

  static const _beirutDowntown = LocationPoint(
    latitude: 33.8938,
    longitude: 35.5018,
    address: 'Downtown, Beirut',
  );

  static const _catalogue = <LocationPoint>[
    LocationPoint(
      latitude: 33.8938,
      longitude: 35.5018,
      address: 'Downtown, Beirut',
    ),
    LocationPoint(
      latitude: 33.8889,
      longitude: 35.4955,
      address: 'Hamra Street, Beirut',
    ),
    LocationPoint(
      latitude: 33.8869,
      longitude: 35.5131,
      address: 'Gemmayze, Beirut',
    ),
    LocationPoint(
      latitude: 33.8703,
      longitude: 35.5380,
      address: 'Achrafieh, Beirut',
    ),
    LocationPoint(
      latitude: 33.9081,
      longitude: 35.4806,
      address: 'Verdun, Beirut',
    ),
  ];

  @override
  Future<LocationPoint> resolveCurrentGps() async {
    // The real impl will go through the geocapture-flutter provider; the
    // in-memory variant returns the same canonical default the map widget
    // centres on, so the picker is immediately ready to drag.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _beirutDowntown;
  }

  @override
  Future<List<LocationPoint>> searchAddress(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _catalogue
        .where((p) => (p.address ?? '').toLowerCase().contains(trimmed))
        .toList(growable: false);
  }

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // Pick the nearest catalogue entry — close enough for the in-memory mode.
    LocationPoint? best;
    double bestDistance = double.infinity;
    for (final point in _catalogue) {
      final dLat = point.latitude - latitude;
      final dLng = point.longitude - longitude;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }
    return best?.address;
  }

  @override
  Future<DeliveryLocations> saveDeliveryLocations({
    required LocationPoint pickup,
    required LocationPoint dropoff,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final saved = DeliveryLocations(pickup: pickup, dropoff: dropoff);
    _saved = saved;
    // Touch the clock so test fakes can assert ordering if needed.
    _now();
    return saved;
  }

  @override
  Future<DeliveryLocations?> loadSavedLocations() async => _saved;
}
