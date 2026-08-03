import 'package:dio/dio.dart';

import '../domain/gps_sample.dart';
import '../domain/location_uploader.dart';

/// Dio-backed LocationUploader. POSTs to /location/update with device fix timestamp
/// (not server clock) so gateway can detect stale buffers. Delivery scope gates ingest;
/// route + shape frozen in gateway (LocationController.Update, Tracking/TrackingDtos.cs).
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

  /// 409 is "delivery not in en-route phase" (gateway gate N5). Expected at head/tail of InTransit
  /// (fix races phase flip); MUST be transient (else single tail-race kills loop). Every other 4xx permanent.
  LocationUploadOutcome _outcomeForStatus(int status) {
    if (status >= 200 && status < 300) return LocationUploadOutcome.accepted;
    if (status >= 500) return LocationUploadOutcome.transientFailure;
    if (status == 409) return LocationUploadOutcome.transientFailure;
    return LocationUploadOutcome.permanentFailure;
  }
}
