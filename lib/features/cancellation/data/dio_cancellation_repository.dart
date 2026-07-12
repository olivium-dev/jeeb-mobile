import 'package:dio/dio.dart';

import '../domain/cancellation_repository.dart';
import '../domain/cancellation_result.dart';

/// Dio-backed implementation of [CancellationRepository].
///
/// Endpoint contract verified against Mockoon :3055 (useMockPrefixes=false):
///   POST /v1/deliveries/{id}/cancel
///       body: { "reason": string, "otherDetails"?: string }
///       200  → CancelDeliveryResponse
///       409  → too_late_to_cancel
///
/// Observability: logs `delivery.cancel_requested` and
/// `delivery.cancel_confirmed` per AC5.
class DioCancellationRepository implements CancellationRepository {
  const DioCancellationRepository(this._dio);

  final Dio _dio;

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    _logRequested(deliveryId, reason);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$deliveryId/cancel',
        data: _buildBody(reason, otherDetails),
      );
      final result = _parse(response.data ?? {});
      _logConfirmed(deliveryId);
      return result;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(String reason, String? other) {
    return {
      'reason': reason,
      if (other != null && other.isNotEmpty) 'otherDetails': other,
    };
  }

  CancellationResult _parse(Map<String, dynamic> json) {
    return CancellationResult(
      deliveryId: json['deliveryId'] as String? ?? '',
      weeklyCount: (json['weeklyCount'] as int?) ?? 0,
      retryAfter: _parseDate(json['retryAfter'] as String?),
      strikeCount: json['strikeCount'] as int?,
      restriction: json['restriction'] as String?,
      pendingApproval: (json['pendingApproval'] as bool?) ?? false,
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Never _handleDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409 || status == 422) {
      throw const CancellationTooLateException();
    }
    throw CancellationException(
      e.message ?? 'Unknown cancellation error',
    );
  }

  void _logRequested(String id, String reason) {
    // ignore: avoid_print — structured observability per AC5
    print('[jeeb] delivery.cancel_requested id=$id reason=$reason');
  }

  void _logConfirmed(String id) {
    // ignore: avoid_print — structured observability per AC5
    print('[jeeb] delivery.cancel_confirmed id=$id');
  }
}
