import 'saved_location.dart';

abstract class LocationSelectRepository {
  Future<List<SavedLocation>> fetchSavedAddresses(String userId);
}

enum LocationSelectFailure { network, unknown }

class LocationSelectException implements Exception {
  const LocationSelectException(this.failure, [this.message]);

  final LocationSelectFailure failure;
  final String? message;
}
