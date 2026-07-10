import 'package:dio/dio.dart';

import '../domain/order_repository.dart';
import '../domain/order_summary.dart';

/// Dio-backed [OrderRepository] hitting `GET /deliveries`.
///
/// The gateway returns a JSON envelope of the shape:
/// ```json
/// {
///   "items": [{ "id": "...", "createdAt": "...", "currentStage": "..." }],
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

  static const _path = '/deliveries';

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
          'stage': _stageParam(tab),
          'page': page,
          'limit': pageSize,
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

  /// Per-tab filter value for the delivery-service list contract.
  static String _stageParam(OrderHistoryTab tab) {
    switch (tab) {
      case OrderHistoryTab.active:
        return 'active';
      case OrderHistoryTab.completed:
        return 'completed';
      case OrderHistoryTab.cancelled:
        return 'cancelled';
    }
  }

  static OrderPage _parsePage(
    Map<String, dynamic> json,
    int requestedPage,
    int pageSize,
  ) {
    final rawItems = json['items'] ?? json['shipments'];
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
      createdAt:
          DateTime.tryParse(
            json['createdAt'] as String? ?? json['created_at'] as String? ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pickupAddress: pickup is Map<String, dynamic>
          ? (pickup['address'] as String? ?? '')
          : '',
      dropoffAddress: dropoff is Map<String, dynamic>
          ? (dropoff['address'] as String? ?? '')
          : '',
      status: OrderRequestStatus.parse(
        json['status'] as String? ?? json['currentStage'] as String?,
      ),
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
