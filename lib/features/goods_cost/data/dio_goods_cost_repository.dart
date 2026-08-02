import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

class DioGoodsCostRepository implements GoodsCostRepository {
  const DioGoodsCostRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final bool originGateway;

  @override
  Future<String> fetchCurrency(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        originGateway
            ? '/v1/deliveries/$deliveryId'
            : '/v1/delivery/$deliveryId',
      );
      return _parseCurrency(response.data);
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  @override
  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/$deliveryId/goods-cost',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          'amount': amount,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return GoodsCost(
        deliveryId: (data['deliveryId'] ?? data['id']) as String? ?? deliveryId,
        amount: _parseAmount(data) ?? amount,
        currency: _parseCurrency(data),
      );
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  /// TODO(backender): the gateway should always return an explicit `currency`
  String _parseCurrency(Map<String, dynamic>? json) {
    if (json == null) return 'USD';
    final nested = json['amount'];
    if (nested is Map) {
      final c = nested['currency'];
      if (c is String && c.isNotEmpty) return c;
    }
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    return 'USD';
  }

  double? _parseAmount(Map<String, dynamic> json) {
    final flat = json['amount'];
    if (flat is num) return flat.toDouble();
    if (flat is Map) {
      final v = flat['value'];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  Never _rethrowDio(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const GoodsCostRepositoryException(GoodsCostFailure.network);
    }
    final status = e.response?.statusCode;
    if (status == 404) {
      throw const GoodsCostRepositoryException(GoodsCostFailure.notFound);
    }
    if (status == 400 || status == 422) {
      throw const GoodsCostRepositoryException(GoodsCostFailure.validation);
    }
    throw const GoodsCostRepositoryException(GoodsCostFailure.unknown);
  }
}
