import 'package:dio/dio.dart';

import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// Dio-backed [ActiveDeliveryRepository] (T-MOB-031).
///
/// Endpoints (Mockoon :3055, useMockPrefixes=false):
///   GET  /v1/deliveries/{id}             → JeeberDelivery JSON
///   POST /v1/deliveries/{id}/transition  → body {from, to}
///   200 → {status}  |  422 → invalid transition
class DioActiveDeliveryRepository implements ActiveDeliveryRepository {
  const DioActiveDeliveryRepository(this._dio);

  final Dio _dio;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/deliveries/$deliveryId',
      );
      final data = response.data;
      if (data == null) {
        throw const ActiveDeliveryException(ActiveDeliveryFailure.server);
      }
      return JeeberDelivery.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$deliveryId/transition',
        data: {'from': from.apiValue, 'to': to.apiValue},
      );
      final raw = response.data?['status'] as String?;
      if (raw == null) return to;
      return JeeberDeliveryStatusX.fromApi(raw);
    } on DioException catch (e) {
      throw _mapTransitionError(e);
    }
  }

  ActiveDeliveryException _mapError(DioException e) {
    if (e.response?.statusCode == 404) {
      return const ActiveDeliveryException(ActiveDeliveryFailure.notFound);
    }
    if (_isNetworkError(e)) {
      return const ActiveDeliveryException(ActiveDeliveryFailure.network);
    }
    return ActiveDeliveryException(
      ActiveDeliveryFailure.server,
      'HTTP ${e.response?.statusCode}',
    );
  }

  ActiveDeliveryException _mapTransitionError(DioException e) {
    if (e.response?.statusCode == 422 || e.response?.statusCode == 400) {
      return const ActiveDeliveryException(
        ActiveDeliveryFailure.invalidTransition,
      );
    }
    return _mapError(e);
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;
}
