import 'package:dio/dio.dart';

import '../domain/services/prohibited_item_report_service.dart';

/// Dio-backed [ProhibitedItemReportService]
/// (orders-prohibited-item-report / disputes-prohibited-item-report).
///
/// Speaks the gateway contract; `MockGatewayClient` rewrites
/// `/v1/deliveries/{id}/prohibited-report` to the owning service prefix.
///
/// **Backend built in parallel (jeeb-backend-feature-services).** The route
/// shape is the documented expected contract:
///
///   POST /v1/deliveries/{requestId}/prohibited-report
///     body: { reason, photoUrl? }  → 201 { id, requestId, status }
///
/// WIRING DEPENDENCY: once the gateway publishes the final route shape, update
/// the path / body here in lockstep. The screen + cubit do not change.
class DioProhibitedItemReportService implements ProhibitedItemReportService {
  const DioProhibitedItemReportService(this._dio);

  final Dio _dio;

  @override
  Future<void> report({
    required String requestId,
    required String reason,
    String? photoUrl,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$requestId/prohibited-report',
        data: <String, dynamic>{
          'reason': reason,
          if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        },
      );
    } on DioException catch (e) {
      throw ProhibitedReportException(_map(e));
    }
  }

  ProhibitedReportFailure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ProhibitedReportFailure.network;
    }
    return ProhibitedReportFailure.unknown;
  }
}
