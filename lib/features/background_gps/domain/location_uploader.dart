import 'gps_sample.dart';

/// Outcome of a single `POST /api/location/update` call. The cubit only
/// cares about three branches — anything past `transient` is a retry, a
/// `permanent` failure stops the upload loop and emits an error state.
enum LocationUploadOutcome {
  accepted,
  transientFailure,
  permanentFailure,
}

/// Sends a captured [GpsSample] to the jeeb-gateway, which forwards to
/// `geolocation-service`. Implementations:
///
///   * `HttpLocationUploader` — Dio-backed, production wiring.
///   * `InMemoryLocationUploader` — records every call; tests assert on
///     the recorded list to verify cadence + accuracy-filter behaviour.
abstract class LocationUploader {
  Future<LocationUploadOutcome> upload({
    required String deliveryId,
    required GpsSample sample,
  });
}
