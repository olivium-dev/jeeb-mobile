import 'package:dio/dio.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/order_chat_summary.dart';

class DioOrderChatSummaryRepository implements OrderChatSummaryRepository {
  const DioOrderChatSummaryRepository(
    this._dio, {
    bool? originGateway,
    this.ownerScopedReads = true,
  }) : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final bool originGateway;

  final bool ownerScopedReads;

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async {
    try {
      final deliveryPath = originGateway
          ? '/v1/deliveries/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final delivery = await _getMap(deliveryPath);
      final requestId =
          _str(delivery?['requestId']) ?? _str(delivery?['id']) ?? deliveryId;

      final request = (!ownerScopedReads || requestId.isEmpty)
          ? null
          : await _getMap('/v1/requests/$requestId');

      final etaMinutes = (!ownerScopedReads || requestId.isEmpty)
          ? null
          : await _acceptedOfferEta(requestId);

      final priceLabel = _formatAmount(
        delivery?['amount'] ?? request?['amount'],
      );
      final tierId = _str(delivery?['tierId']) ??
          _str(delivery?['tier_id']) ??
          _str(request?['tierId']) ??
          _str(request?['tier_id']) ??
          _str(delivery?['tier']) ??
          _str(request?['tier']) ??
          '';
      final orderRef = _str(request?['displayId']) ??
          _str(delivery?['displayId']) ??
          '';
      final jeeberName = _str(delivery?['jeeberName']) ??
          _str(request?['jeeberName']) ??
          '';
      // Counterparty identity is delivery-only on purpose: the jeeber leg never
      // reads /v1/requests (owner-scoped), and both parties need the same source.
      final jeeberAvatarUrl = _str(delivery?['jeeberAvatarUrl']) ?? '';
      final clientName = _str(delivery?['clientName']) ?? '';
      final clientAvatarUrl = _str(delivery?['clientAvatarUrl']) ?? '';
      final rating = _num(delivery?['jeeberRating']) ??
          _num(request?['jeeberRating']) ??
          0;
      final statusId =
          _str(delivery?['status']) ?? _str(request?['status']) ?? '';

      final description = _str(delivery?['description']) ??
          _str(request?['description']) ??
          _str(delivery?['title']) ??
          '';

      if (delivery == null && request == null) {
        throw const OrderChatSummaryException(OrderChatSummaryFailure.notFound);
      }

      return OrderChatSummary(
        deliveryId: deliveryId,
        requestId: requestId,
        priceLabel: priceLabel,
        jeeberName: jeeberName,
        jeeberAvatarUrl: jeeberAvatarUrl,
        clientName: clientName,
        clientAvatarUrl: clientAvatarUrl,
        rating: rating,
        etaMinutes: etaMinutes,
        tierId: tierId,
        orderRef: orderRef,
        statusId: statusId,
        description: description,
      );
    } on OrderChatSummaryException {
      rethrow;
    } on DioException catch (e) {
      throw OrderChatSummaryException(_map(e));
    } catch (_) {
      throw const OrderChatSummaryException(OrderChatSummaryFailure.unknown);
    }
  }

  Future<Map<String, dynamic>?> _getMap(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<int?> _acceptedOfferEta(String requestId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/offers',
        queryParameters: <String, Object?>{'requestId': requestId},
      );
      final items = res.data?['items'];
      if (items is! List) return null;
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
    return MoneyFormat.format(value, currency: currency);
  }

  String? _str(Object? v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;
}
