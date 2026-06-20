import 'package:dio/dio.dart';

import '../domain/masked_call_repository.dart';

/// Dio-backed [MaskedCallRepository] (orders-masked-call).
///
/// Speaks the gateway contract; `MockGatewayClient` rewrites
/// `/v1/deliveries/{id}/masked-call` to the owning service prefix.
///
/// **Backend built in parallel (jeeb-backend-feature-services).** Documented
/// expected contract:
///
///   POST /v1/deliveries/{orderId}/masked-call
///     → 200 { sessionId, proxyNumber, expiresAt? }
///
/// WIRING DEPENDENCY: once the gateway publishes the final route + payload
/// shape, update the path / response parse here in lockstep. The cubit + button
/// do not change.
class DioMaskedCallRepository implements MaskedCallRepository {
  const DioMaskedCallRepository(this._dio);

  final Dio _dio;

  @override
  Future<MaskedCallSession> requestSession({required String orderId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$orderId/masked-call',
      );
      final data = response.data ?? const <String, dynamic>{};
      final proxy = (data['proxyNumber'] ?? data['proxy_number']) as String?;
      if (proxy == null || proxy.isEmpty) {
        throw const MaskedCallException(MaskedCallFailure.unavailable);
      }
      final expiresRaw = (data['expiresAt'] ?? data['expires_at']) as String?;
      return MaskedCallSession(
        sessionId: (data['sessionId'] ?? data['session_id'] ?? '') as String,
        proxyNumber: proxy,
        expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
      );
    } on DioException catch (e) {
      throw MaskedCallException(_map(e));
    }
  }

  MaskedCallFailure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return MaskedCallFailure.network;
    }
    return MaskedCallFailure.unavailable;
  }
}
