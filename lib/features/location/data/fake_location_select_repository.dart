import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';

/// In-memory [LocationSelectRepository] — a constructor test seam ONLY
/// (40_GUARDRAILS_ARCH §6 / DO-NOT: never registered in DI). Lets widget tests
/// + the dev seam render the location-select screen end-to-end without a
/// backend.
class FakeLocationSelectRepository implements LocationSelectRepository {
  const FakeLocationSelectRepository({
    this.addresses = defaultAddresses,
    this.failWith,
  });

  /// When non-null, [fetchSavedAddresses] throws — exercises the cubit's error
  /// branch without a Dio mock.
  final LocationSelectFailure? failWith;

  final List<SavedLocation> addresses;

  /// Mirrors the `has_saved_addresses` mock seed (Home default + Office).
  static const List<SavedLocation> defaultAddresses = [
    SavedLocation(
      id: 'addr-client-001-home',
      label: 'Home',
      latitude: 33.8886,
      longitude: 35.4955,
      category: SavedLocationCategory.home,
      address: 'Sassine Square, Ashrafieh',
    ),
    SavedLocation(
      id: 'addr-client-001-office',
      label: 'Office',
      latitude: 33.8938,
      longitude: 35.5018,
      category: SavedLocationCategory.work,
      address: 'Beirut Tower, Downtown',
    ),
  ];

  @override
  Future<List<SavedLocation>> fetchSavedAddresses(String userId) async {
    final failure = failWith;
    if (failure != null) throw LocationSelectException(failure);
    return addresses;
  }
}
