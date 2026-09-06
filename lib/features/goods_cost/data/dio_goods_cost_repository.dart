import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

class DioGoodsCostRepository implements GoodsCostRepository {
  const DioGoodsCostRepository(this._dio, {bool? originGateway})
    : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final bool originGateway;

  /// Keeps `Future<String>` (R3: three implementors, one in `lib/devtool`) and
  /// signals an absent currency by throwing instead of inventing `USD`.
  @override
  Future<String> fetchCurrency(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        originGateway
            ? '/v1/deliveries/$deliveryId'
            : '/v1/delivery/$deliveryId',
      );
      final currency = _parseCurrency(response.data);
      if (currency == null) {
        throw const GoodsCostRepositoryException(
          GoodsCostFailure.currencyUnavailable,
        );
      }
      return currency;
    } on GoodsCostRepositoryException {
      rethrow;
    } on DioException catch (e) {
      _throw(AppFailure.of(e));
    } catch (e) {
      _throw(AppFailure.of(e));
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
        data: <String, dynamic>{'deliveryId': deliveryId, 'amount': amount},
      );
      final data = response.data ?? const <String, dynamic>{};
      final confirmed = _parseAmount(data);
      // Echoing the client's own amount back would report a confirmation the
      // server never gave (UX-22 class).
      if (confirmed == null) {
        throw const GoodsCostRepositoryException(
          GoodsCostFailure.amountUnconfirmed,
          cause: UnknownFailure(parse: true),
        );
      }
      return GoodsCost(
        deliveryId: (data['deliveryId'] ?? data['id']) as String? ?? deliveryId,
        amount: confirmed,
        currency: _parseCurrency(data),
      );
    } on GoodsCostRepositoryException {
      rethrow;
    } on DioException catch (e) {
      _throw(AppFailure.of(e));
    } catch (e) {
      _throw(AppFailure.of(e));
    }
  }

  String? _parseCurrency(Map<String, dynamic>? json) {
    if (json == null) return null;
    final nested = json['amount'];
    if (nested is Map) {
      final c = nested['currency'];
      if (c is String && c.isNotEmpty) return c;
    }
    final flat = json['currency'];
    if (flat is String && flat.isNotEmpty) return flat;
    return null;
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

  Never _throw(AppFailure f) {
    throw switch (f) {
      NetworkFailure() || TimeoutFailure() => GoodsCostRepositoryException(
        GoodsCostFailure.network,
        cause: f,
      ),
      NotFoundFailure() || GoneFailure() => GoodsCostRepositoryException(
        GoodsCostFailure.notFound,
        cause: f,
      ),
      ValidationFailure() => GoodsCostRepositoryException(
        GoodsCostFailure.validation,
        cause: f,
      ),
      _ => GoodsCostRepositoryException(GoodsCostFailure.unknown, cause: f),
    };
  }
}
