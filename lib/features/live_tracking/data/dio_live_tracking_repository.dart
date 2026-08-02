import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

class DioLiveTrackingRepository
    implements LiveTrackingRepository, LivePositionSource {
  DioLiveTrackingRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final bool originGateway;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    try {
      final path = originGateway
          ? '/v1/deliveries/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data;
      if (data == null) {
        throw const LiveTrackingException(LiveTrackingErrorKind.parse);
      }
      return DeliveryTrackingInfo.fromDeliveryJson(deliveryId, data);
    } on DioException catch (e) {
      final LiveTrackingErrorKind kind;
      if (e.response == null) {
        kind = LiveTrackingErrorKind.network;
      } else if (e.response!.statusCode == 404) {
        kind = LiveTrackingErrorKind.notFound;
      } else {
        kind = LiveTrackingErrorKind.server;
      }
      throw LiveTrackingException(kind, e);
    } on FormatException catch (e) {
      throw LiveTrackingException(LiveTrackingErrorKind.parse, e);
    }
  }

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async {
    if (!originGateway) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/deliveries/$deliveryId/tracking',
      );
      final data = response.data;
      if (data == null) return null;
      final info = DeliveryTrackingInfo.fromTrackingJson(deliveryId, data);
      return DeliveryLivePosition(
        jeeberPosition: info.jeeberPosition,
        polyline: info.polyline,
        stale: info.positionStale,
        secondsSinceUpdate: info.positionAgeSeconds,
        status: info.positionStatus,
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
