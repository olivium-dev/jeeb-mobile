import 'package:dio/dio.dart';

import '../domain/order_chat_summary.dart';

/// Dio-backed [OrderChatSummaryRepository] (JM-025 AC2).
///
/// Reads the locked pinned-summary fields from the existing mock services via
/// the gateway-contract paths (the `MockGatewayClient` interceptor rewrites the
/// `/v1/...` prefix to the `:4010` service prefix — never hardcode a prefix):
///
///   GET /v1/delivery/:deliveryId    → price (amount), tier, jeeberName, requestId
///   GET /v1/requests/:requestId     → orderRef (displayId), tier fallback, amount fallback
///   GET /v1/offers?requestId=…       → accepted offer's etaMinutes
///
/// Every read is defensive: a missing delivery falls back to the request row,
/// a missing field is simply omitted from the summary (the strip hides that
/// chip). Only a hard transport failure raises [OrderChatSummaryException]; a
/// 404 maps to [OrderChatSummaryFailure.notFound] so the caller can hide the
/// strip rather than break the chat thread.
class DioOrderChatSummaryRepository implements OrderChatSummaryRepository {
  const DioOrderChatSummaryRepository(this._dio);

  final Dio _dio;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async {
    try {
      final delivery = await _getMap('/v1/delivery/$deliveryId');
      final requestId =
          _str(delivery?['requestId']) ?? _str(delivery?['id']) ?? deliveryId;

      // The request row carries the human order ref (`displayId`) + tier; the
      // delivery row carries the locked price + winner name. Fetch the request
      // for the ref/tier; tolerate its absence.
      final request = requestId.isEmpty ? null : await _getMap('/v1/requests/$requestId');

      // ETA is the *winning* (accepted) offer's eta — read from the offers
      // list for this request. Tolerate an empty/absent list.
      final etaMinutes =
          requestId.isEmpty ? null : await _acceptedOfferEta(requestId);

      final priceLabel = _formatAmount(
        delivery?['amount'] ?? request?['amount'],
      );
      final tierId = _str(delivery?['tier']) ?? _str(request?['tier']) ?? '';
      final orderRef = _str(request?['displayId']) ??
          _str(delivery?['displayId']) ??
          '';
      final jeeberName = _str(delivery?['jeeberName']) ??
          _str(request?['jeeberName']) ??
          '';
      final rating = _num(delivery?['jeeberRating']) ??
          _num(request?['jeeberRating']) ??
          0;

      if (delivery == null && request == null) {
        throw const OrderChatSummaryException(OrderChatSummaryFailure.notFound);
      }

      return OrderChatSummary(
        deliveryId: deliveryId,
        requestId: requestId,
        priceLabel: priceLabel,
        jeeberName: jeeberName,
        rating: rating,
        etaMinutes: etaMinutes,
        tierId: tierId,
        orderRef: orderRef,
      );
    } on OrderChatSummaryException {
      rethrow;
    } on DioException catch (e) {
      throw OrderChatSummaryException(_map(e));
    } catch (_) {
      throw const OrderChatSummaryException(OrderChatSummaryFailure.unknown);
    }
  }

  /// GET a JSON object, returning null on 404 (so the caller can fall back to
  /// the other source) and rethrowing any other transport error.
  Future<Map<String, dynamic>?> _getMap(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Reads the accepted offer's ETA for [requestId]. Returns null when no
  /// offer is accepted yet or the field is absent.
  Future<int?> _acceptedOfferEta(String requestId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/offers',
        queryParameters: <String, Object?>{'requestId': requestId},
      );
      final items = res.data?['items'];
      if (items is! List) return null;
      // Prefer an explicitly accepted offer; fall back to the first offer so a
      // not-yet-accepted-but-matched order still shows an indicative ETA.
      Map<String, dynamic>? chosen;
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        if (_str(raw['status']) == 'accepted') {
          chosen = raw;
          break;
        }
        chosen ??= raw;
      }
      final eta = chosen?['etaMinutes'];
      return eta is num ? eta.toInt() : null;
    } on DioException {
      return null;
    }
  }

  OrderChatSummaryFailure _map(DioException e) {
    if (e.response?.statusCode == 404) return OrderChatSummaryFailure.notFound;
    return (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout)
        ? OrderChatSummaryFailure.network
        : OrderChatSummaryFailure.unknown;
  }

  /// Formats an amount object (`{ value, minorUnits, currency }` per the mock
  /// `usd()` shape) or a bare number into a `$9.00`-style label. Returns ''
  /// when the input carries no usable value (the strip then hides the chip).
  String _formatAmount(Object? amount) {
    double? value;
    String currency = 'USD';
    if (amount is Map) {
      final v = amount['value'];
      if (v is num) value = v.toDouble();
      final c = amount['currency'];
      if (c is String && c.isNotEmpty) currency = c;
    } else if (amount is num) {
      value = amount.toDouble();
    }
    if (value == null) return '';
    final symbol = currency == 'USD' ? r'$' : '';
    return '$symbol${value.toStringAsFixed(2)}'
        '${symbol.isEmpty ? ' $currency' : ''}';
  }

  String? _str(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;
}
