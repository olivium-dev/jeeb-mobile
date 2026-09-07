// Shared dev-only fixtures for `SavedLocationsScreen`.

import 'dart:async';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/cubit/saved_locations_cubit.dart';
import 'package:jeeb_mobile/features/location/presentation/cubit/saved_locations_state.dart';

/// Canned [SavedLocationRepository] — reads return [locations], writes
/// synthesize a row. No Dio, no GetIt, no network.
/// `const`-constructible so the catalog can keep building
class SavedLocationsScreenFakeRepository implements SavedLocationRepository {
  const SavedLocationsScreenFakeRepository(
    this.locations, {
    this.failFetch = false,
  });

  /// What `GET /users/:userId/saved-locations` resolves to.
  final List<SavedLocation> locations;

  /// When true the read throws a [SavedLocationException], which is how the
  /// live BFF fails — not a null and not an empty list. Drives the screen's
  final bool failFetch;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    if (failFetch) throw const SavedLocationException('fetch_failed');
    return locations;
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      SavedLocation(
        id: 'new-$label',
        label: label,
        latitude: latitude,
        longitude: longitude,
        category: category,
        address: address,
      );

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      SavedLocation(
        id: id,
        label: label,
        latitude: latitude,
        longitude: longitude,
        category: category,
        address: address,
      );

  @override
  Future<void> deleteLocation(String id) async {}
}

/// A read that never lands, holding the screen on `SavedLocationsLoading` for
/// as long as the surface is open.
/// The cubit emits `SavedLocationsLoading` from `load()` and only leaves it when
/// A read that throws a classified [AppFailure] — the only way the error
/// rung's kind-aware copy (403 vs 429 vs 503) becomes reviewable.
class SavedLocationsScreenFailingRepository
    extends SavedLocationsScreenFakeRepository {
  const SavedLocationsScreenFailingRepository(this.failure)
      : super(const <SavedLocation>[]);

  final AppFailure failure;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => throw failure;
}

class SavedLocationsScreenPendingRepository
    extends SavedLocationsScreenFakeRepository {
  const SavedLocationsScreenPendingRepository()
      : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

/// M4: the delete / set-default overlay, which no still frame reached before —
/// it needed a tap plus a write that never lands. The real cubit over the
/// canned repository, parked on `SavedLocationsMutating`.
class SavedLocationsScreenMutatingCubit extends SavedLocationsCubit {
  SavedLocationsScreenMutatingCubit()
      : super(
          const SavedLocationsScreenFakeRepository(
            savedLocationsScreenHomeAndOffice,
          ),
        ) {
    emit(const SavedLocationsMutating(savedLocationsScreenHomeAndOffice));
  }
}

/// The `has_saved_addresses` seam seed (63_W1_TEST_PLAN §4.1): `Home` is the
/// default address (it carries `saved_address_default_badge`), `Office` is not.
const List<SavedLocation> savedLocationsScreenHomeAndOffice = <SavedLocation>[
  SavedLocation(
    id: 'addr-home',
    label: 'Home',
    latitude: 33.8886,
    longitude: 35.4955,
    category: SavedLocationCategory.home,
    address: 'Sassine Square, Ashrafieh',
    isDefault: true,
  ),
  SavedLocation(
    id: 'addr-office',
    label: 'Office',
    latitude: 33.8938,
    longitude: 35.5018,
    category: SavedLocationCategory.work,
    address: 'Beirut Tower, Downtown',
  ),
];

/// A full shelf: TEN addresses, the cap the gateway enforces
/// ([SavedLocationCapReachedException] / `savedLocationsCapReached`).
final List<SavedLocation> savedLocationsScreenAtCap = <SavedLocation>[
  const SavedLocation(
    id: 'addr-souks',
    label: 'Beirut Souks — Parking Level B2, Weygand Street entrance',
    latitude: 33.8975,
    longitude: 35.5062,
    category: SavedLocationCategory.other,
    address: 'Beirut Souks, Weygand Street, Beirut Central District, Lebanon',
    isDefault: true,
  ),
  const SavedLocation(
    id: 'addr-teta',
    label: 'Teta',
    latitude: 33.8912,
    longitude: 35.4955,
    category: SavedLocationCategory.other,
  ),
  for (int i = 3; i <= 10; i++)
    SavedLocation(
      id: 'addr-other-$i',
      label: 'Saved address $i',
      latitude: 33.88 + i / 1000,
      longitude: 35.50 + i / 1000,
      category: SavedLocationCategory.other,
      address: 'Beirut, street $i',
    ),
];
