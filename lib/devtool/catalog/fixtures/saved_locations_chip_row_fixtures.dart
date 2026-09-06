// Designed states for `SavedLocationsChipRow` — the saved-address strip above
// the map picker. Lifted out of the widget's own preview section so the new
// failure rung is reviewable from the catalog without touching a batch file.

import 'dart:async';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';

/// The two rows every populated state is reviewed with.
const SavedLocation savedLocationsChipRowHome = SavedLocation(
  id: 'addr-client-001-home',
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
  isDefault: true,
);

const SavedLocation savedLocationsChipRowOffice = SavedLocation(
  id: 'addr-client-001-office',
  label: 'Office',
  latitude: 33.8938,
  longitude: 35.5018,
  category: SavedLocationCategory.work,
  address: 'Downtown Beirut',
);

/// Answers [locations]; every mutation is out of scope for this strip.
class SavedLocationsChipRowFakeRepository implements SavedLocationRepository {
  const SavedLocationsChipRowFakeRepository(this.locations);

  final List<SavedLocation> locations;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => locations;

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) =>
      throw UnimplementedError();

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteLocation(String id) => throw UnimplementedError();
}

/// The read never lands — the strip stays collapsed.
class SavedLocationsChipRowPendingRepository
    extends SavedLocationsChipRowFakeRepository {
  const SavedLocationsChipRowPendingRepository()
      : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

/// The read FAILS — distinct from "no saved locations", which shrinks.
class SavedLocationsChipRowFailingRepository
    extends SavedLocationsChipRowFakeRepository {
  const SavedLocationsChipRowFailingRepository({
    this.failure = const ServerFailure(status: 500),
  }) : super(const <SavedLocation>[]);

  final AppFailure failure;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => throw failure;
}
