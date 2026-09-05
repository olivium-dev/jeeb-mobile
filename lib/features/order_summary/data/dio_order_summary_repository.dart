import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
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

    final requestRead = await _tryFetch('/v1/requests/$requestId');
    final request = requestRead.data;
    final offersRead = await _tryAcceptedOfferEta(requestId);
    final jeeberRead = jeeberId == null
        ? const (data: null, failed: false)
        : await _tryFetch('/v1/users/$jeeberId');
    final jeeber = jeeberRead.data;

    // A failed secondary read is not an absent field: the screen says so.
    final partial = <OrderSummarySection>{
      if (requestRead.failed) OrderSummarySection.request,
      if (offersRead.failed) OrderSummarySection.offers,
      if (jeeberRead.failed) OrderSummarySection.jeeber,
    };

    return OrderSummary(
      deliveryId: _str(delivery['id']) ?? deliveryId,
      requestId: requestId,
      conversationId: _str(
        delivery['conversationId'] ??
            delivery['conversation_id'] ??
            request?['conversationId'] ??
            request?['conversation_id'],
      ),
      partialSections: partial,
      price: _money(delivery['amount'] ?? request?['amount']),
      currency: _currency(delivery['amount'] ?? request?['amount']),
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
      etaMinutes: offersRead.data ??
          _toInt(delivery['etaMinutes'] ?? request?['etaMinutes']),
      itemSummary: _str(delivery['title'] ?? request?['title']),
      jeeberAvatarUrl:
          _str(delivery['jeeberAvatarUrl'] ?? jeeber?['avatarUrl']),
    );
  }

  Future<({Map<String, dynamic>? data, bool failed})> _tryFetch(
    String path,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      return (data: res.data, failed: false);
    } catch (_) {
      return (data: null, failed: true);
    }
  }

  Future<({int? data, bool failed})> _tryAcceptedOfferEta(
    String requestId,
  ) async {
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
        return (data: null, failed: false);
      }
      final maps = items.whereType<Map<String, dynamic>>();
      final accepted = maps.where((o) => _str(o['status']) == 'accepted');
      final chosen = accepted.isNotEmpty ? accepted.first : null;
      return (
        data: _toInt(chosen?['etaMinutes'] ?? chosen?['eta_minutes']),
        failed: false,
      );
    } catch (_) {
      return (data: null, failed: true);
    }
  }

  /// Only a real String: `raw?.toString()` rendered a decoded List or Map
  /// literal straight onto the screen.
  static String? _str(Object? raw) {
    if (raw is! String) return null;
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
    throw OrderSummaryRepositoryException(
      switch (AppFailure.of(e).kind) {
        AppFailureKind.network ||
        AppFailureKind.timeout =>
          OrderSummaryFailure.network,
        AppFailureKind.notFound ||
        AppFailureKind.gone =>
          OrderSummaryFailure.notFound,
        AppFailureKind.unauthorized ||
        AppFailureKind.forbidden =>
          OrderSummaryFailure.forbidden,
        _ => OrderSummaryFailure.unknown,
      },
    );
  }
}
