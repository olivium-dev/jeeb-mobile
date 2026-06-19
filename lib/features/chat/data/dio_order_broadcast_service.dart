import 'package:dio/dio.dart';

import '../domain/order_broadcast_service.dart';

/// Dio-backed [OrderBroadcastService] (JM-025 AC1, D83 / JM-026).
///
/// Speaks the gateway-contract paths (the `MockGatewayClient` interceptor
/// rewrites the `/v1/...` prefix to the `:4010` service prefix):
///
///   POST /v1/matching/find-jeebers  → { count, jeeberIds, … } (notified count)
///   POST /v1/matching/broadcast     → 202 (fire-and-forget broadcast)
///
/// `find-jeebers` is best-effort: a failure there does not abort the broadcast
/// (the request is already pending); we default `notifiedCount` to 0 so the
/// waiting screen shows its no-coverage variant. `broadcast` returning 202 is
/// the authoritative "request is now live" signal. The request itself is
/// created/pinned by the upstream create-leg (JM-024); this service only flips
/// it live and reports coverage.
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
      // Fire the broadcast (202, no body). A non-2xx here is the only hard
      // failure — without it the request never goes live.
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

  /// Counts nearby Jeebers. Best-effort: any failure yields 0 (no-coverage)
  /// rather than aborting the broadcast.
  Future<int> _findJeebers(String requestId, String tier) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/matching/find-jeebers',
        data: <String, Object?>{
          'requestId': requestId,
          // The mock requires tier + origin; default to a reachable tier when
          // the create-leg did not thread one through, so the count call 200s.
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
