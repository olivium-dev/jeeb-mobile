import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// Dio-backed [ActiveDeliveryRepository] (T-MOB-031, extended by JM-051).
///
/// Speaks the gateway-contract `/v1/...` paths; `MockGatewayClient` rewrites
/// the prefix to the `:4010` `delivery-service` (40_GUARDRAILS_ARCH §4 — never
/// hardcode a host/prefix here).
///
///   GET  /v1/delivery/{id}              → delivery JSON
///   POST /v1/delivery/status/transition → body { deliveryId, to, evidenceUrl? }
///                                          200 → delivery | 422 → bad transition
///   POST /v1/delivery/proof-photo       → body { deliveryId, filename }
///                                          201 → { url, evidenceUrl, deliveryId }
class DioActiveDeliveryRepository implements ActiveDeliveryRepository {
  const DioActiveDeliveryRepository(this._dio);

  final Dio _dio;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/delivery/$deliveryId',
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
    String? evidenceUrl,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/status/transition',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          'to': to.apiValue,
          'trigger': 'jeeber',
          if (evidenceUrl != null && evidenceUrl.isNotEmpty)
            'evidenceUrl': evidenceUrl,
        },
      );
      // The transition endpoint returns the full delivery row; read its status.
      final raw = response.data?['status'] as String?;
      if (raw == null) return to;
      return JeeberDeliveryStatusX.fromApi(raw);
    } on DioException catch (e) {
      throw _mapTransitionError(e);
    }
  }

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
    Uint8List? bytes,
  }) async {
    try {
      // Real device capture → multipart upload to the cdn-service via the
      // gateway (`POST /v1/delivery/proof-photo` carries the image part). The
      // gateway proxies the bytes to cdn-service and returns the minted
      // evidence URL. When no bytes are supplied (the in-memory mock seam that
      // does not store bytes) we degrade to the legacy filename-only JSON post.
      final Object payload;
      if (bytes != null) {
        payload = FormData.fromMap(<String, dynamic>{
          'deliveryId': deliveryId,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        });
      } else {
        payload = <String, dynamic>{
          'deliveryId': deliveryId,
          'filename': filename,
        };
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/proof-photo',
        data: payload,
        options: Options(
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      final url = response.data?['evidenceUrl'] as String? ??
          response.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        throw const ActiveDeliveryException(ActiveDeliveryFailure.server);
      }
      return url;
    } on DioException catch (e) {
      throw _mapError(e);
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
