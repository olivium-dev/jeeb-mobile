import 'package:dio/dio.dart';

import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

/// T-MOB-017: Repository uses the verified mock paths:
///   GET /deliveries/{id}/tracking → TrackingPolylineDto
///   GET /v1/geo/jeeb/stream/{id}  → same shape (mobile alias, also REST)
///
/// Endpoint contract verified against Mockoon :3055 (d6-tracking-geo suite,
/// scenario s09-live-tracking).  useMockPrefixes=false, paths pass through.
class DioLiveTrackingRepository implements LiveTrackingRepository {
  DioLiveTrackingRepository(this._dio);

  final Dio _dio;

  // Verified path: GET /deliveries/{id}/tracking → 200 TrackingPolylineDto
  // (ETag header + polyline array + position object)
  static const _trackingPath = '/deliveries';

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_trackingPath/$deliveryId/tracking',
      );
      final data = response.data;
      if (data == null) {
        throw const LiveTrackingException(LiveTrackingErrorKind.parse);
      }
      return DeliveryTrackingInfo.fromTrackingJson(deliveryId, data);
    } on DioException catch (e) {
      throw LiveTrackingException(
        e.response == null
            ? LiveTrackingErrorKind.network
            : LiveTrackingErrorKind.server,
        e,
      );
    } on FormatException catch (e) {
      throw LiveTrackingException(LiveTrackingErrorKind.parse, e);
    }
  }
}
