import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../../kyc/domain/cdn_asset_gateway.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

class DioActiveDeliveryRepository implements ActiveDeliveryRepository {
  const DioActiveDeliveryRepository(
    this._dio, {
    required CdnAssetGateway cdnAssetGateway,
    bool? originGateway,
  })  : _cdn = cdnAssetGateway,
        originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final CdnAssetGateway _cdn;

  final bool originGateway;

  static const _v1DeliveriesPath = '/v1/deliveries';

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    try {
      final path = originGateway
          ? '$_v1DeliveriesPath/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final response = await _dio.get<Map<String, dynamic>>(path);
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
      final response = originGateway
          ? await _dio.patch<Map<String, dynamic>>(
              '$_v1DeliveriesPath/$deliveryId/status',
              data: <String, dynamic>{
                'to': to.apiValue,
                'evidenceUrl':
                    (evidenceUrl != null && evidenceUrl.isNotEmpty)
                        ? evidenceUrl
                        : null,
              },
            )
          : await _dio.post<Map<String, dynamic>>(
              '/v1/delivery/status/transition',
              data: <String, dynamic>{
                'deliveryId': deliveryId,
                'to': to.apiValue,
                'trigger': 'jeeber',
                if (evidenceUrl != null && evidenceUrl.isNotEmpty)
                  'evidenceUrl': evidenceUrl,
              },
            );
      final raw = response.data?['status'] as String?;
      if (raw == null) return to;
      return JeeberDeliveryStatusX.fromApi(raw);
    } on DioException catch (e) {
      throw _mapTransitionError(e, from: from, to: to);
    }
  }

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async {
    try {
      try {
        await _dio.get<Map<String, dynamic>>(
          '$_v1DeliveriesPath/$deliveryId/otp',
        );
      } on DioException {
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '$_v1DeliveriesPath/$deliveryId/otp/verify',
        data: <String, dynamic>{'code': code},
      );
      final data = response.data ?? const <String, dynamic>{};
      final raw = data['status'] as String?;
      if (raw != null) return JeeberDeliveryStatusX.fromApi(raw);
      final verified = data['verified'] as bool? ?? true;
      return verified
          ? JeeberDeliveryStatus.done
          : JeeberDeliveryStatus.atDoor;
    } on DioException catch (e) {
      throw _mapOtpError(e);
    }
  }

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      return await _cdn.uploadAsset(
        slot: CdnUploadSlot.proofOfDelivery,
        bytes: bytes,
        contentType: contentType,
      );
    } on CdnUploadException {
      throw const ActiveDeliveryException(ActiveDeliveryFailure.server);
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

  ActiveDeliveryException _mapTransitionError(
    DioException e, {
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  }) {
    final status = e.response?.statusCode;

    if (status == 400) {
      return ActiveDeliveryException(
        ActiveDeliveryFailure.badRequest,
        _reasonToken(e.response?.data),
      );
    }

    if (status == 422) {
      final reason = _reasonToken(e.response?.data);
      if (reason == 'otp_required') {
        return const ActiveDeliveryException(ActiveDeliveryFailure.otpRequired);
      }
      if (from == JeeberDeliveryStatus.atDoor &&
          to == JeeberDeliveryStatus.done) {
        return const ActiveDeliveryException(ActiveDeliveryFailure.otpRequired);
      }
      return ActiveDeliveryException(
        ActiveDeliveryFailure.invalidTransition,
        reason,
      );
    }

    return _mapError(e);
  }

  String? _reasonToken(Object? body) {
    if (body is! Map) return null;
    for (final key in const ['reason', 'code', 'detail', 'error', 'message']) {
      final v = body[key];
      if (v is String && v.trim().isNotEmpty) return v.trim().toLowerCase();
      if (v is Map) {
        final nested = v['reason'] ?? v['code'] ?? v['message'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim().toLowerCase();
        }
      }
    }
    return null;
  }

  ActiveDeliveryException _mapOtpError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 400 || status == 422) {
      if (status == 404) {
        return const ActiveDeliveryException(ActiveDeliveryFailure.notFound);
      }
      return const ActiveDeliveryException(ActiveDeliveryFailure.invalidOtp);
    }
    if (status == 423) {
      return const ActiveDeliveryException(ActiveDeliveryFailure.otpLocked);
    }
    return _mapError(e);
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;
}
