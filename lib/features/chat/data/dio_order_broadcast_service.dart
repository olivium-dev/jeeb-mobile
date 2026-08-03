import 'package:dio/dio.dart';

import '../domain/order_broadcast_service.dart';

class DioOrderBroadcastService implements OrderBroadcastService {
  const DioOrderBroadcastService(this._dio);

  final Dio _dio;

  @override
  Future<OrderBroadcastResult> broadcast({
    required String conversationId,
    required String requestId,
    String tier = '',
  }) async {
    final effectiveRequestId =
        requestId.isNotEmpty ? requestId : conversationId;
    try {
      final notifiedCount = await _findJeebers(effectiveRequestId, tier);
      await _dio.post<void>(
        '/v1/matching/broadcast',
        data: <String, Object?>{'requestId': effectiveRequestId},
      );
      return OrderBroadcastResult(
        requestId: effectiveRequestId,
        notifiedCount: notifiedCount,
      );
    } on DioException catch (e) {
      throw OrderBroadcastException(_map(e));
    } catch (_) {
      throw const OrderBroadcastException(OrderBroadcastFailure.unknown);
    }
  }

  Future<int> _findJeebers(String requestId, String tier) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/matching/find-jeebers',
        data: <String, Object?>{
          'requestId': requestId,
          'tier': tier.isNotEmpty ? tier : 'express',
          'origin': <String, Object?>{'lat': 0, 'lng': 0},
        },
      );
      final count = res.data?['count'];
      return count is num ? count.toInt() : 0;
    } on DioException {
      return 0;
    }
  }

  OrderBroadcastFailure _map(DioException e) {
    final code = e.response?.statusCode ?? 0;
    if (code == 400) return OrderBroadcastFailure.badRequest;
    return (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout)
        ? OrderBroadcastFailure.network
        : OrderBroadcastFailure.unknown;
  }
}
