import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

class DioDeliveryReceiptRepository implements DeliveryReceiptRepository {
  const DioDeliveryReceiptRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final bool originGateway;

  static const String _confirmedStatus = 'Done';

  static bool _isTerminalStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'done' || s == 'delivered' || s == 'completed';
  }

  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        originGateway
            ? '/v1/deliveries/$deliveryId'
            : '/v1/delivery/$deliveryId',
      );
      return _parseReceipt(deliveryId, response.data);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async {
    if (_isTerminalStatus(receipt.status)) {
      return;
    }
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/v1/deliveries/${receipt.deliveryId}/status',
        data: <String, dynamic>{
          'to': _confirmedStatus,
          'trigger': 'customer_confirmed_receipt',
        },
        options: Options(
          headers: <String, Object?>{
            'Idempotency-Key': receiptConfirmIdempotencyKey(
              receipt.deliveryId,
            ),
          },
        ),
      );
    } on DioException catch (e) {
      // A refused transition is NOT a confirmation: returning here fires the
      // confirmed overlay and the rating on a delivery the gateway declined.
      if (e.response?.statusCode == 422) {
        throw const DeliveryReceiptRepositoryException(
          DeliveryReceiptFailure.transitionNotAllowed,
        );
      }
      _rethrowDio(e);
    }
  }

  DeliveryReceipt _parseReceipt(String deliveryId, Map<String, dynamic>? data) {
    if (data == null) {
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.unknown,
      );
    }
    final proof = DeliveryReceipt.normalizeProofEvidence(data['proofPhotoUrl']) ??
        DeliveryReceipt.normalizeProofEvidence(data['evidenceUrl']);
    final rawJeeberId = (data['jeeberId'] ?? data['jeeber_id']) as String?;
    final jeeberId = (rawJeeberId != null && rawJeeberId.trim().isNotEmpty)
        ? rawJeeberId
        : null;
    return DeliveryReceipt(
      deliveryId: (data['id'] as String?) ?? deliveryId,
      jeeberName: (data['jeeberName'] ?? data['jeeber_name']) as String? ?? '',
      jeeberId: jeeberId,
      cashAmount: _parseAmount(data),
      currency: _parseCurrency(data),
      status: (data['status'] as String?) ?? '',
      proofPhotoUrl: proof,
    );
  }

  double? _parseAmount(Map<String, dynamic> json) {
    final flat = json['amount'];
    if (flat is num) return flat.toDouble();
    return _moneyValue(json['amount']) ?? _moneyValue(json['price']);
  }

  String? _parseCurrency(Map<String, dynamic> json) {
    final fromObject =
        _moneyCurrency(json['amount']) ?? _moneyCurrency(json['price']);
    if (fromObject != null) return fromObject;
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    return null;
  }

  double? _moneyValue(dynamic money) {
    if (money is Map) {
      final v = money['value'];
      if (v is num) return v.toDouble();
      final minor = money['minorUnits'];
      if (minor is num) return minor.toDouble() / 100;
    }
    return null;
  }

  String? _moneyCurrency(dynamic money) {
    if (money is Map) {
      final c = money['currency'];
      if (c is String && c.isNotEmpty) return c;
    }
    return null;
  }

  Never _rethrowDio(DioException e) {
    final AppFailure failure = AppFailure.of(e);
    throw DeliveryReceiptRepositoryException(
      switch (failure.kind) {
        AppFailureKind.network ||
        AppFailureKind.timeout =>
          DeliveryReceiptFailure.network,
        AppFailureKind.notFound || AppFailureKind.gone =>
          DeliveryReceiptFailure.notFound,
        AppFailureKind.unauthorized ||
        AppFailureKind.forbidden =>
          DeliveryReceiptFailure.forbidden,
        _ => DeliveryReceiptFailure.unknown,
      },
    );
  }

}

/// One key per delivery: a replayed or re-tapped confirm settles the same row
/// once, never twice.
String receiptConfirmIdempotencyKey(String deliveryId) => sha256
    .convert(utf8.encode('receipt-confirm:$deliveryId'))
    .toString();
