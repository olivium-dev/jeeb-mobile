import 'saved_location.dart';

/// Repository for saved locations (T-MOB-012 / T-MOB-025).
///
/// Endpoints — VERIFIED against the live gateway `:10090` (2026-06-30). The
/// live BFF keys the collection on the authenticated user (`me`) under `/api`;
/// the concrete path is resolved by `MockGatewayClient.savedLocationsPath`
/// (mock mode emits the `:userId`-keyed `/users/…` shape instead):
///   GET    /api/users/me/saved-locations        -> 200 {userId, items, defaultId}
///   POST   /api/users/me/saved-locations        -> 201 (top-level latitude/longitude)
///   PUT    /api/users/me/saved-locations/{id}
///   DELETE /api/users/me/saved-locations/{id}    -> 204
abstract class SavedLocationRepository {
  /// Fetches the user's saved locations.
  /// Endpoint: `GET /api/users/me/saved-locations`
  Future<List<SavedLocation>> fetchSavedLocations();

  /// Creates a new saved location (returns HTTP 201).
  /// Endpoint: `POST /api/users/me/saved-locations`
  /// Throws [SavedLocationCapReachedException] on HTTP 409/422 (cap of 10).
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  });

  /// Updates an existing saved location.
  /// Endpoint: `PUT /api/users/me/saved-locations/{id}`
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  });

  /// Deletes a saved location.
  /// Endpoint: `DELETE /api/users/me/saved-locations/{id}`
  /// Returns `204 No Content` on success.
  Future<void> deleteLocation(String id);
}

/// Thrown when the server returns 409 indicating the 10-location cap.
class SavedLocationCapReachedException implements Exception {
  const SavedLocationCapReachedException();
}

/// Generic saved-location failure.
class SavedLocationException implements Exception {
  const SavedLocationException(this.message);

  final String message;
}
