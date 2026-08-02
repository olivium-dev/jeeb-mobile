// Shared dev-only fixtures for `SavedLocationsScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_06_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/location/presentation/saved_locations_screen.dart`.
//
// The catalog owned a private `_StaticSavedLocationRepository` plus a `seeded`
// list; copying that into the preview section would have given the two surfaces
// two different accounts, free to drift. Both now import this file, so a change
// to the fixture account shows up in the catalog and in the canvas together.
//
// Everything here is a LOCAL fake: `SavedLocationsScreen` takes a
// `repository:` seam, so neither surface ever resolves the Dio-backed
// `DioSavedLocationRepository` out of GetIt. Network-free by construction, not
// merely by the guard the hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';

/// Canned [SavedLocationRepository] — reads return [locations], writes
/// synthesize a row. No Dio, no GetIt, no network.
///
/// `const`-constructible so the catalog can keep building
/// `const SavedLocationsScreen(repository: ...)`.
class SavedLocationsScreenFakeRepository implements SavedLocationRepository {
  const SavedLocationsScreenFakeRepository(
    this.locations, {
    this.failFetch = false,
  });

  /// What `GET /users/:userId/saved-locations` resolves to.
  final List<SavedLocation> locations;

  /// When true the read throws a [SavedLocationException], which is how the
  /// live BFF fails — not a null and not an empty list. Drives the screen's
  /// `SavedLocationsError` branch.
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
///
/// The cubit emits `SavedLocationsLoading` from `load()` and only leaves it when
/// the future completes, so this is the only way to inspect the spinner (and
/// the inert Add CTA that sits over it) without a real slow connection.
class SavedLocationsScreenPendingRepository
    extends SavedLocationsScreenFakeRepository {
  const SavedLocationsScreenPendingRepository()
      : super(const <SavedLocation>[]);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

/// The `has_saved_addresses` seam seed (63_W1_TEST_PLAN §4.1): `Home` is the
/// default address (it carries `saved_address_default_badge`), `Office` is not.
///
/// The same account `test/saved_locations_screen_test.dart` drives, so the
/// catalog, the canvas and the widget suite all describe one user.
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
///
/// Deliberately the worst list the cap makes plausible, because the tile is a
/// single [Row] that has to hold an icon, a label, the default badge and two
/// icon buttons:
///
///   * row 0 carries the longest label AND the longest address a user can
///     realistically save, AND the default badge — the three things that
///     compete for the same horizontal run;
///   * row 1 has NO `address`, which is the tile's other layout (title only,
///     no subtitle);
///   * rows 2-9 fill the list past one screen so the scroll behaviour is real.
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
