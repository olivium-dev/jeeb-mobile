import 'package:dio/dio.dart';

import '../domain/gps_sample.dart';
import '../domain/location_uploader.dart';

/// Dio-backed [LocationUploader].
///
/// JEBV4-269: posts the jeeber's live GPS fix to the SHIPPED jeeb-gateway
/// ingest endpoint so the customer's live-tracking map has data. The gateway
/// route + wire shape are frozen (`LocationController.Update`,
/// `Tracking/TrackingDtos.cs`):
///
///   POST /location/update
///   {
///     "deliveryId": "delivery-...",           // S09 delivery scope (JEB-54)
///     "points": [
///       { "lat": 33.88, "lng": 35.50,
///         "accuracy": 12.3,
///         "timestamp": "2026-05-17T14:23:11.000Z" }   // device fix time
///     ]
///   }
///
/// The delivery-scoped shape (`deliveryId` present) makes the gateway resolve
/// the delivery's parties via delivery-service and gate the ingest BEFORE any
/// write: a non-party is 403'd (N2) and a fix outside the en-route (InTransit)
/// phase is 409'd (N5) — and the latest accepted fix is forwarded to the
/// canonical presence store as a heartbeat (S06 A2). The gateway owns the
/// geolocation-service hop; the mobile app never touches it directly
/// (boundaries §1). The customer reads the same fix back via
/// `GET /deliveries/{id}/tracking`.
///
/// The batch-of-one shape (rather than the `{deliveryId, lat, lng}`
/// single-point convenience form) is used so the DEVICE fix timestamp is
/// preserved end-to-end for the gateway's stale-detection (`stale > 2 min`)
/// instead of being re-stamped with the server clock.
class HttpLocationUploader implements LocationUploader {
  HttpLocationUploader({required Dio dio, this.path = '/location/update'})
      : _dio = dio;

  final Dio _dio;
  final String path;

  @override
  Future<LocationUploadOutcome> upload({
    required String deliveryId,
    required GpsSample sample,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          'points': <Map<String, dynamic>>[
            <String, dynamic>{
              'lat': sample.latitude,
              'lng': sample.longitude,
              'accuracy': sample.accuracyMeters,
              'timestamp': sample.capturedAt.toUtc().toIso8601String(),
            },
          ],
        },
      );
      return _outcomeForStatus(response.statusCode ?? 0);
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          return LocationUploadOutcome.transientFailure;
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
          return LocationUploadOutcome.permanentFailure;
        case DioExceptionType.badResponse:
          return _outcomeForStatus(e.response?.statusCode ?? 0);
        case DioExceptionType.transformTimeout:
        case DioExceptionType.unknown:
          return LocationUploadOutcome.transientFailure;
      }
    }
  }

  /// Maps an HTTP status onto an upload outcome.
  ///
  /// A 409 is the gateway's "delivery is not in the en-route phase" gate (N5):
  /// it is expected at the head/tail of an InTransit window (e.g. a fix that
  /// races an `InTransit → AtDoor` flip) and must NOT be treated as permanent —
  /// otherwise a single tail-race would kill the upload loop. It is retryable
  /// (transient); the [ActiveDeliveryCubit] lifecycle stops the loop cleanly
  /// once the delivery genuinely leaves InTransit. Every other 4xx (404 missing
  /// row, 401/403 auth) IS permanent so the loop stops rather than hammering
  /// the gateway.
  LocationUploadOutcome _outcomeForStatus(int status) {
    if (status >= 200 && status < 300) return LocationUploadOutcome.accepted;
    if (status >= 500) return LocationUploadOutcome.transientFailure;
    if (status == 409) return LocationUploadOutcome.transientFailure;
    return LocationUploadOutcome.permanentFailure;
  }
}
