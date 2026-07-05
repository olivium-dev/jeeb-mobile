import 'package:dio/dio.dart';

import '../../../core/formatting/server_time.dart';
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

  // Gateway-contract path. MUST carry exactly one `/v1` (ARCH-01/INFRA-01
  // anti-drift contract in app_config.dart): the base URL is origin-only, so a
  // bare `/requests` (no `/v1`) 404s on the live gateway and never rewrites in
  // the mock (§6B DEFECT-A). Mirrors the customer request list (`/v1/requests`).
  static const _path = '/v1/requests';

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
      return _parsePage(response.data, tab, page, pageSize);
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
    Object? data,
    OrderHistoryTab tab,
    int requestedPage,
    int pageSize,
  ) {
    final rawItems = _items(data);
    if (rawItems.isEmpty && data is! List) {
      throw const FormatException('items missing or not a list');
    }
    final items = <OrderSummary>[];
    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        final order = _parseOrder(raw);
        // Lane item 6 / run-22 P1-B: the tabs must ACTUALLY filter. The
        // server-side `status=` filter is advisory — gateways have been
        // observed returning loosely-filtered rows and the canonical-vs-legacy
        // vocabulary drifts. Re-bucket client-side so a `Done` order can never
        // linger under Active and Completed/Cancelled only show terminals.
        // `unknown` statuses stay visible on the Active tab by design (see
        // OrderRequestStatus.tab) rather than being dropped everywhere.
        if (order.status.tab != tab) continue;
        items.add(order);
      }
    }
    return OrderPage(
      items: items,
      page: requestedPage,
      // Derived from the WIRE page size, not the filtered count — a page the
      // server filled completely may still have more, even if re-bucketing
      // trimmed rows locally.
      hasMore: rawItems.length >= pageSize,
    );
  }

  static OrderSummary _parseOrder(Map<String, dynamic> json) {
    final amount = json['amount'];
    final pickup = json['pickup'];
    final dropoff = json['dropoff'];
    return OrderSummary(
      id: json['id'] as String? ?? '',
      // SW-03 family: the requests list carries UTC instants; a zone-less
      // string parsed raw would render as the device-local wall clock. Normalize
      // to a UTC instant here (shared ServerTime) so the card's `.toLocal()` is
      // a real conversion, not a no-op.
      createdAt:
          ServerTime.parse(json['createdAt'] as String?) ??
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
      // Same wire drift as the receipt (run-22 P1-A): the live gateway sends
      // a FLAT numeric `"amount": 12` in major units; older shapes send
      // `{ minorUnits, currency }`. Accept both. T11 / SW-02: an ABSENT amount
      // is UNKNOWN → null (the card degrades to "—"), NEVER a fabricated 0 that
      // renders as `$0.00`. The old `_ => 0` fallback is exactly what made every
      // row read `$0.00`.
      amountMinor: switch (amount) {
        final num flat => (flat * 100).round(),
        {'minorUnits': final num minor} => minor.round(),
        {'value': final num value} => (value * 100).round(),
        _ => null,
      },
      currency: amount is Map<String, dynamic>
          ? (amount['currency'] as String? ?? 'USD')
          : (json['currency'] as String? ?? 'USD'),
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
