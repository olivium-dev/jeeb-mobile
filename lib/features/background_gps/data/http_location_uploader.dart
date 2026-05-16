import 'package:dio/dio.dart';

import '../domain/gps_sample.dart';
import '../domain/location_uploader.dart';

/// Dio-backed [LocationUploader].
///
/// Endpoint contract (JEEB-73, jeeb-gateway):
///   POST /api/location/update
///   {
///     "delivery_id": "...",
///     "latitude": 33.88, "longitude": 35.50,
///     "accuracy_m": 12.3, "speed_mps": 4.1,
///     "heading_deg": 92.0,
///     "recorded_at": "2026-05-17T14:23:11.000Z"
///   }
///
/// jeeb-gateway forwards to `geolocation-service` — the mobile app
/// never hits geolocation-service directly (boundaries §1).
class HttpLocationUploader implements LocationUploader {
  HttpLocationUploader({required Dio dio, this.path = '/api/location/update'})
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
        data: {
          'delivery_id': deliveryId,
          'latitude': sample.latitude,
          'longitude': sample.longitude,
          'accuracy_m': sample.accuracyMeters,
          'speed_mps': sample.speedMps,
          'heading_deg': sample.headingDegrees,
          'recorded_at': sample.capturedAt.toUtc().toIso8601String(),
        },
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return LocationUploadOutcome.accepted;
      if (status >= 500) return LocationUploadOutcome.transientFailure;
      // 4xx — delivery doesn't exist, auth expired, etc. Permanent so the
      // cubit stops the loop rather than hammering the gateway.
      return LocationUploadOutcome.permanentFailure;
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
          final status = e.response?.statusCode ?? 0;
          if (status >= 500) return LocationUploadOutcome.transientFailure;
          return LocationUploadOutcome.permanentFailure;
        case DioExceptionType.unknown:
          return LocationUploadOutcome.transientFailure;
      }
    }
  }
}
