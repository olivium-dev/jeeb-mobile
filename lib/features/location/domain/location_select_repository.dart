import 'saved_location.dart';

/// Read side of the `location-select` step (JM-024). The screen lists the
/// user's saved addresses (so a returning customer can pick one in a tap) plus
/// the always-present "Current Location" + "New Location" affordances.
///
/// Read side of the saved-locations resource. As of the iter6 DEFECT-B path
/// consolidation the Dio impl ([DioLocationSelectRepository]) speaks the SAME
/// canonical `me`-scoped gateway path as the JM-049 manager
/// ([SavedLocationRepository]) and the JM-050 form: `GET /api/users/me/
/// saved-locations` (identity from the bearer token), so all saved-locations
/// reads/writes share one contract and the picker can no longer drift onto the
/// mock-only `/users/:userId/...` alias.
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
