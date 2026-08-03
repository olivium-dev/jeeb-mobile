import 'package:dio/dio.dart';

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
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        return;
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
    final rawProof = (data['proofPhotoUrl'] ?? data['evidenceUrl']) as String?;
    final proof =
        (rawProof != null && rawProof.trim().isNotEmpty) ? rawProof : null;
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

  String _parseCurrency(Map<String, dynamic> json) {
    final fromObject =
        _moneyCurrency(json['amount']) ?? _moneyCurrency(json['price']);
    if (fromObject != null) return fromObject;
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    return 'USD';
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
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.network,
      );
    }
    if (e.response?.statusCode == 404) {
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.notFound,
      );
    }
    throw const DeliveryReceiptRepositoryException(
      DeliveryReceiptFailure.unknown,
    );
  }

}
