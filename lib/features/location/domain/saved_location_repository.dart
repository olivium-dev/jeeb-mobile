import 'saved_location.dart';

abstract class SavedLocationRepository {
  Future<List<SavedLocation>> fetchSavedLocations();

  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  });

  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  });

  Future<void> deleteLocation(String id);
}

class SavedLocationCapReachedException implements Exception {
  const SavedLocationCapReachedException();
}

class SavedLocationException implements Exception {
  const SavedLocationException(this.message);

  final String message;
}
