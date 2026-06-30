import 'package:dio/dio.dart';

import '../domain/order_repository.dart';
import '../domain/order_summary.dart';

/// Dio-backed [OrderRepository] hitting `GET /requests`.
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

  static const _path = '/requests';

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    try {
      final response = await _dio.get<dynamic>(
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
      return _parsePage(response.data, page, pageSize);
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

  static OrderPage _parsePage(Object? data, int requestedPage, int pageSize) {
    final rawItems = _items(data);
    if (rawItems.isEmpty && data is! List) {
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
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pickupAddress: pickup is Map<String, dynamic>
          ? (pickup['address'] as String? ?? '')
          : (json['pickupAddress'] as String? ?? ''),
      dropoffAddress: dropoff is Map<String, dynamic>
          ? (dropoff['address'] as String? ?? '')
          : (json['dropoffAddress'] as String? ?? ''),
      status: OrderRequestStatus.parse(json['status'] as String?),
      tier: OrderTier.parse(
        json['tier'] as String? ?? json['tierId'] as String?,
      ),
      amountMinor: amount is Map<String, dynamic>
          ? (amount['minorUnits'] as int? ?? 0)
          : 0,
      currency: amount is Map<String, dynamic>
          ? (amount['currency'] as String? ?? 'USD')
          : 'USD',
    );
  }

  static List<dynamic> _items(Object? data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return data['items'] as List;
    }
    return const <dynamic>[];
  }
}
