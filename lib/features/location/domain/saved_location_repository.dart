import 'saved_location.dart';

/// Repository for saved locations (T-MOB-012 / T-MOB-025).
///
/// Endpoints per Mockoon :3055 contract (d1-auth-identity.contract.md):
///   GET    /v1/users/me/saved-locations
///   POST   /v1/users/me/saved-locations
///   PUT    /v1/users/me/saved-locations/{id}
///   DELETE /v1/users/me/saved-locations/{id}
abstract class SavedLocationRepository {
  /// Fetches the user's saved locations.
  /// Endpoint: `GET /v1/users/me/saved-locations`
  Future<List<SavedLocation>> fetchSavedLocations();

  /// Creates a new saved location (returns HTTP 201).
  /// Endpoint: `POST /v1/users/me/saved-locations`
  /// Throws [SavedLocationCapReachedException] on HTTP 409 (cap of 10).
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  });

  /// Updates an existing saved location.
  /// Endpoint: `PUT /v1/users/me/saved-locations/{id}`
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  });

  /// Deletes a saved location.
  /// Endpoint: `DELETE /v1/users/me/saved-locations/{id}`
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
