import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';

/// so a malformed body degrades a field gracefully instead of crashing.
class DioOrderSummaryRepository implements OrderSummaryRepository {
  const DioOrderSummaryRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final bool originGateway;

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async {
    final Map<String, dynamic> delivery;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        originGateway
            ? '/v1/deliveries/$deliveryId'
            : '/v1/delivery/$deliveryId',
      );
      final data = res.data;
      if (data == null) {
        throw const OrderSummaryRepositoryException(
          OrderSummaryFailure.unknown,
        );
      }
      delivery = data;
    } on DioException catch (e) {
      _rethrowDelivery(e);
    }

    final requestId = _str(delivery['requestId'] ?? delivery['request_id']) ??
        deliveryId; // mock convention: deliveryId == accepted-request-id.
    final jeeberId = _str(delivery['jeeberId'] ?? delivery['jeeber_id']);

    final request = await _tryFetch('/v1/requests/$requestId');
    final acceptedEta = await _tryAcceptedOfferEta(requestId);
    final jeeber =
        jeeberId == null ? null : await _tryFetch('/v1/users/$jeeberId');

    final conversationId = _str(
          delivery['conversationId'] ??
              delivery['conversation_id'] ??
              request?['conversationId'] ??
              request?['conversation_id'],
        ) ??
        '';

    return OrderSummary(
      deliveryId: _str(delivery['id']) ?? deliveryId,
      requestId: requestId,
      conversationId: conversationId,
      price: _money(delivery['amount'] ?? request?['amount']) ?? 0.0,
      currency: _currency(delivery['amount'] ?? request?['amount']) ?? 'USD',
      jeeberName: _str(
            delivery['jeeberName'] ??
                delivery['jeeber_name'] ??
                jeeber?['name'] ??
                request?['jeeberName'],
          ) ??
          (jeeberId ?? ''),
      tier: _str(
            delivery['tierId'] ??
                delivery['tier_id'] ??
                request?['tierId'] ??
                request?['tier_id'] ??
                delivery['tier'] ??
                request?['tier'],
          ) ??
          '',
      jeeberRating: _toDouble(jeeber?['rating']),
      jeeberRatingCount: _toInt(jeeber?['ratingCount'] ?? jeeber?['rating_count']),
      etaMinutes: acceptedEta ??
          _toInt(delivery['etaMinutes'] ?? request?['etaMinutes']),
      itemSummary: _str(delivery['title'] ?? request?['title']),
      jeeberAvatarUrl:
          _str(delivery['jeeberAvatarUrl'] ?? jeeber?['avatarUrl']),
    );
  }

  Future<Map<String, dynamic>?> _tryFetch(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return res.data;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _tryAcceptedOfferEta(String requestId) async {
    try {
      final res = await _dio.get<dynamic>(
        '/v1/offers',
        queryParameters: {'requestId': requestId},
      );
      final data = res.data;
      final List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        items = (data['items'] as List?) ?? (data['offers'] as List?) ?? const [];
      } else {
        return null;
      }
      final maps = items.whereType<Map<String, dynamic>>();
      final accepted = maps.where((o) => _str(o['status']) == 'accepted');
      final chosen = accepted.isNotEmpty ? accepted.first : null;
      return _toInt(chosen?['etaMinutes'] ?? chosen?['eta_minutes']);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _str(Object? raw) {
    if (raw is! String) return raw?.toString();
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _money(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map) {
      final value = raw['value'] ?? raw['amount'];
      if (value is num) return value.toDouble();
      final minor = raw['minorUnits'] ?? raw['minor_units'];
      if (minor is num) return minor.toDouble() / 100.0;
    }
    return null;
  }

  static String? _currency(Object? raw) {
    if (raw is Map) return _str(raw['currency']);
    return null;
  }

  static double? _toDouble(Object? raw) =>
      raw is num ? raw.toDouble() : null;

  static int? _toInt(Object? raw) => raw is num ? raw.toInt() : null;

  Never _rethrowDelivery(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw const OrderSummaryRepositoryException(OrderSummaryFailure.network);
    }
    if (e.response?.statusCode == 404) {
      throw const OrderSummaryRepositoryException(OrderSummaryFailure.notFound);
    }
    throw const OrderSummaryRepositoryException(OrderSummaryFailure.unknown);
  }
}
