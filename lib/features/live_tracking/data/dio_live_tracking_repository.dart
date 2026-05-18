import 'package:dio/dio.dart';

import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

class DioLiveTrackingRepository implements LiveTrackingRepository {
  DioLiveTrackingRepository(this._dio);

  final Dio _dio;

  static const _basePath = '/v1/delivery';

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_basePath/$deliveryId',
      );
      final data = response.data;
      if (data == null) {
        throw const LiveTrackingException(LiveTrackingErrorKind.parse);
      }
      return DeliveryTrackingInfo.fromJson(deliveryId, data);
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
