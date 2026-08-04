import 'package:equatable/equatable.dart';

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

abstract class LocationRepository {
  Future<LocationPoint> resolveCurrentGps();

  Future<List<LocationPoint>> searchAddress(String query);

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  Future<DeliveryLocations> saveDeliveryLocations({
    required LocationPoint pickup,
    required LocationPoint dropoff,
  });

  Future<DeliveryLocations?> loadSavedLocations();
}

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
    _now();
    return saved;
  }

  @override
  Future<DeliveryLocations?> loadSavedLocations() async => _saved;
}
