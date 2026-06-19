import 'saved_location.dart';

/// Read side of the `location-select` step (JM-024). The screen lists the
/// user's saved addresses (so a returning customer can pick one in a tap) plus
/// the always-present "Current Location" + "New Location" affordances.
///
/// Distinct from [SavedLocationRepository] (the JM-049 CRUD manager, which
/// speaks the legacy `/v1/users/me/saved-locations` shape): this read-only
/// source speaks the **journey-honest** mock contract
/// `GET /user-management/users/:userId/saved-locations` (via the gateway path
/// `/users/:userId/saved-locations`, 42_GUARDRAILS_MOCK §4 / `has_saved_addresses`
/// seed) so the W1 seeded addresses actually surface in the picker.
///
/// PURE Dart — no Flutter / Dio / GetIt (40_GUARDRAILS_ARCH §1).
abstract class LocationSelectRepository {
  /// Returns the saved addresses for [userId]. Implementations degrade a
  /// malformed/empty body to an empty list (the screen still renders the
  /// current/new affordances), and throw [LocationSelectException] only on a
  /// transport failure so the cubit can show its error state.
  Future<List<SavedLocation>> fetchSavedAddresses(String userId);
}

/// The single failure the `location-select` read can surface. Kept narrow on
/// purpose — the screen renders one retry banner regardless of cause.
enum LocationSelectFailure { network, unknown }

class LocationSelectException implements Exception {
  const LocationSelectException(this.failure, [this.message]);

  final LocationSelectFailure failure;
  final String? message;
}
