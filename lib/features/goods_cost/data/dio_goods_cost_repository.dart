import 'package:dio/dio.dart';

import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

/// Dio-backed [GoodsCostRepository].
///
/// Endpoints (gateway contract; `MockGatewayClient` rewrites the `/v1/...`
/// prefix to the `:4010` service prefix — 40_GUARDRAILS_ARCH §4/§11). NEVER
/// hardcode a `:4010` host or a service prefix here.
///   GET  `/v1/delivery/:deliveryId` → `/delivery-service/v1/delivery/:id`
///         — the delivery row. Read ONLY to learn the gateway-authoritative
///           currency for the entry-field label (flat `currency` or the nested
///           `amount: { value, currency }` money object; the mock stamps flat).
///   POST `/v1/delivery/:deliveryId/goods-cost` → `/delivery-service/...`
///         — records the goods cost the Jeeber declares. Idempotent on
///           `deliveryId`. The response echoes the recorded `{ amount,
///           currency }` so the currency stays gateway-verbatim end-to-end.
///
/// TODO(integrator/backender): the `POST /v1/delivery/:deliveryId/goods-cost`
/// route is requested but not yet present in the mock (`42_GUARDRAILS_MOCK` /
/// `50_ROUTE_REQUESTS.md`). Until it lands the live POST returns 404 and the
/// cubit surfaces a retryable error; the GET-currency read already works
/// against the existing `/v1/delivery/:id` route. Do NOT fall back to a
/// client-side fake here — the integrator wires the real route.
class DioGoodsCostRepository implements GoodsCostRepository {
  const DioGoodsCostRepository(this._dio);

  final Dio _dio;

  @override
  Future<String> fetchCurrency(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/delivery/$deliveryId',
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
          // The gross goods cost the Jeeber typed. No fee / commission / FX
          // math — the platform economics are a server concern (D11).
          'amount': amount,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return GoodsCost(
        deliveryId: (data['deliveryId'] ?? data['id']) as String? ?? deliveryId,
        // Echo the gateway-confirmed amount when present, else the value sent.
        amount: _parseAmount(data) ?? amount,
        // Currency is gateway-verbatim (40_GUARDRAILS_ARCH §5).
        currency: _parseCurrency(data),
      );
    } on DioException catch (e) {
      _rethrowDio(e);
    }
  }

  /// Defensive currency parse — accept the nested `{ value, currency }` money
  /// object or a flat `currency` string (the mock stamps flat). When the
  /// gateway omits a currency entirely, default to `USD`.
  ///
  /// TODO(backender): the gateway should always return an explicit `currency`
  /// (flat or nested) on the delivery + goods-cost record so the client never
  /// has to default. Tracked alongside the goods-cost route request.
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
