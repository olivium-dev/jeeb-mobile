import 'gps_sample.dart';

/// Outcome of POST /api/location/update; only three branches matter:
/// transient failures retry, permanent failure stops loop and emits error.
enum LocationUploadOutcome {
  accepted,
  transientFailure,
  permanentFailure,
}

/// Sends GpsSample to jeeb-gateway → geolocation-service.
/// Implementations: HttpLocationUploader (Dio, production) or InMemoryLocationUploader (test mock).
abstract class LocationUploader {
  Future<LocationUploadOutcome> upload({
    required String deliveryId,
    required GpsSample sample,
  });
}
