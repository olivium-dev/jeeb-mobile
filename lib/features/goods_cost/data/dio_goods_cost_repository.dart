import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

/// Dio-backed [GoodsCostRepository].
///
/// Endpoints (gateway contract; `MockGatewayClient` rewrites the `/v1/...`
/// prefix to the `:4010` service prefix — 40_GUARDRAILS_ARCH §4/§11). NEVER
/// hardcode a `:4010` host or a service prefix here.
///   GET  `/v1/deliveries/:deliveryId` → the delivery aggregate. Read ONLY to
///           learn the gateway-authoritative currency for the entry-field label
///           (flat `currency` or the nested `amount: { value, currency }` money
///           object; the mock stamps flat). BUG-8: origin plural route.
///   POST `/v1/delivery/:deliveryId/goods-cost` → `/delivery-service/...`
///         — records the goods cost the Jeeber declares. Idempotent on
///           `deliveryId`. The response echoes the recorded `{ amount,
///           currency }` so the currency stays gateway-verbatim end-to-end.
///           This is a GENUINELY different endpoint (a goods-cost command, NOT
///           the delivery read) — it stays SINGULAR, deliberately NOT rewritten.
///
/// BUG-8 (sprint-008 run-7): only the currency READ moved to the base-aware
/// plural `GET /v1/deliveries/{id}` (the singular alias 404s on the live origin
/// gateway; the materialized aggregate lives at the plural route — Contract 8c).
/// Pattern reused verbatim from `DioActiveDeliveryRepository` (T-MOB-031).
///
/// TODO(integrator/backender): the `POST /v1/delivery/:deliveryId/goods-cost`
/// route is requested but not yet present in the mock (`42_GUARDRAILS_MOCK` /
/// `50_ROUTE_REQUESTS.md`). Until it lands the live POST returns 404 and the
/// cubit surfaces a retryable error; the GET-currency read already works
/// against the delivery aggregate route. Do NOT fall back to a client-side fake
/// here — the integrator wires the real route.
class DioGoodsCostRepository implements GoodsCostRepository {
  /// [originGateway] selects the wire shape for the currency delivery READ. When
  /// `true` (the device/real default) it speaks the FROZEN plural `:10090` route
  /// `GET /v1/deliveries/{id}` (BUG-8 fix); when `false` it speaks the legacy
  /// `:4010` mock alias `GET /v1/delivery/{id}`. The default mirrors the base
  /// selection (`!MockGatewayClient.useMockPrefixes`).
  const DioGoodsCostRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  /// Whether to read the frozen origin `:10090` plural delivery route
  /// (`GET /v1/deliveries/{id}`) instead of the legacy `:4010` mock singular
  /// alias (`GET /v1/delivery/{id}`). Only the READ is affected — the goods-cost
  /// POST stays singular. See the constructor doc.
  final bool originGateway;

  @override
  Future<String> fetchCurrency(String deliveryId) async {
    try {
      // Origin `:10090` reads the plural `/v1/deliveries/{id}` (Contract 8c);
      // the `:4010` mock keeps the legacy singular `/v1/delivery/{id}` alias.
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
