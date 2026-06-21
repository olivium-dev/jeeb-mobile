import 'package:dio/dio.dart';

import '../domain/order_repository.dart';
import '../domain/order_summary.dart';

/// Dio-backed [OrderRepository] hitting `GET /v1/requests`.
///
/// §6B DEFECT-A (S22 re-capture): this used to hit the dead `GET /api/requests`
/// prefix, which the gateway has NO controller for (`RequestsController` is
/// `[Route("requests")]` → `/requests` / `/v1/requests`). The jeeber Delivery
/// (order-history) tab therefore 404'd ("Couldn't load orders"), while the
/// CUSTOMER list — which already calls the contract `/v1/requests` path — loaded
/// fine. Corrected to the gateway-contract `/v1/requests` (caller-scoped by the
/// bearer token, like the customer list; `status`/`page`/`pageSize` forwarded).
///
/// The gateway returns a JSON envelope of the shape:
/// ```json
/// {
///   "items": [{ "id": "...", "createdAt": "...", ... }],
///   "page": 1,
///   "pageSize": 20,
///   "totalCount": 142
/// }
/// ```
/// `hasMore` is derived as `items.length == pageSize` so we don't depend on
/// `totalCount` (the gateway is allowed to skip it for cheap queries).
class DioOrderRepository implements OrderRepository {
  DioOrderRepository(this._dio);

  final Dio _dio;

  static const _path = '/v1/requests';

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {
          'status': _statusParam(tab),
          'page': page,
          'pageSize': pageSize,
          if (range.from != null)
            'fromDate': range.from!.toUtc().toIso8601String(),
          if (range.to != null) 'toDate': range.to!.toUtc().toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const OrderRepositoryException(OrderRepositoryErrorKind.parse);
      }
      return _parsePage(data, page, pageSize);
    } on DioException catch (e) {
      throw OrderRepositoryException(
        e.response == null
            ? OrderRepositoryErrorKind.network
            : OrderRepositoryErrorKind.server,
        e,
      );
    } on FormatException catch (e) {
      throw OrderRepositoryException(OrderRepositoryErrorKind.parse, e);
    }
  }

  /// Per-tab filter value. The gateway interprets these:
  /// - `active` → any non-terminal state
  /// - `delivered` → only successfully completed
  /// - `cancelled` → cancelled or disputed
  static String _statusParam(OrderHistoryTab tab) {
    switch (tab) {
      case OrderHistoryTab.active:
        return 'active';
      case OrderHistoryTab.completed:
        return 'delivered';
      case OrderHistoryTab.cancelled:
        return 'cancelled';
    }
  }

  static OrderPage _parsePage(
    Map<String, dynamic> json,
    int requestedPage,
    int pageSize,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('items missing or not a list');
    }
    final items = <OrderSummary>[];
    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        items.add(_parseOrder(raw));
      }
    }
    return OrderPage(
      items: items,
      page: requestedPage,
      hasMore: items.length >= pageSize,
    );
  }

  static OrderSummary _parseOrder(Map<String, dynamic> json) {
    final amount = json['amount'];
    final pickup = json['pickup'];
    final dropoff = json['dropoff'];
    return OrderSummary(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pickupAddress: pickup is Map<String, dynamic>
          ? (pickup['address'] as String? ?? '')
          : '',
      dropoffAddress: dropoff is Map<String, dynamic>
          ? (dropoff['address'] as String? ?? '')
          : '',
      status: OrderRequestStatus.parse(json['status'] as String?),
      tier: OrderTier.parse(json['tier'] as String?),
      amountMinor: amount is Map<String, dynamic>
          ? (amount['minorUnits'] as int? ?? 0)
          : 0,
      currency: amount is Map<String, dynamic>
          ? (amount['currency'] as String? ?? 'USD')
          : 'USD',
    );
  }
}
