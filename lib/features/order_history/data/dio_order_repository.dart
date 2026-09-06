import 'package:dio/dio.dart';

import '../../../core/formatting/server_time.dart';
import '../../../core/network/app_failure.dart';
import '../domain/order_repository.dart';
import '../domain/order_summary.dart';

/// Dio-backed [OrderRepository] hitting `GET /requests`.
class DioOrderRepository implements OrderRepository {
  DioOrderRepository(this._dio, {bool asJeeber = false}) : _asJeeber = asJeeber;

  final Dio _dio;

  final bool _asJeeber;

  // Gateway-contract paths. MUST carry exactly one `/v1` (ARCH-01/INFRA-01).
  static const _customerPath = '/v1/requests';
  static const _jeeberPath = '/v1/deliveries';

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        _asJeeber ? _jeeberPath : _customerPath,
        queryParameters: {
          // Status param drives bucket (terminal Done/Cancelled excluded). Omitting it returned only active rows.
          if (_asJeeber) 'role': 'jeeber',
          'status': _statusParam(tab),
          'page': page,
          'pageSize': pageSize,
          if (range.from != null)
            'fromDate': range.from!.toIso8601String(),
          if (range.to != null)
            'toDate': range.to!.toIso8601String(),
        },
      );
      return _parsePage(response.data, tab, page, pageSize);
    } on DioException catch (e) {
      final AppFailure failure = AppFailure.of(e);
      throw OrderRepositoryException(
        failure is NetworkFailure || failure is TimeoutFailure
            ? OrderRepositoryErrorKind.network
            : OrderRepositoryErrorKind.server,
        e,
        failure,
      );
    } on FormatException catch (e) {
      throw OrderRepositoryException(
        OrderRepositoryErrorKind.parse,
        e,
        UnknownFailure(cause: e, parse: true),
      );
    } on OrderRepositoryException {
      rethrow;
    } catch (e) {
      // A numeric `id` used to throw TypeError past both catches and strand the
      // tab in loadingFirstPage.
      throw OrderRepositoryException(
        OrderRepositoryErrorKind.parse,
        e,
        UnknownFailure(cause: e, parse: true),
      );
    }
  }

  /// Per-tab filter value. Gateway interprets: `active` → non-terminal state.
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
    if (data is Map<String, dynamic> && data['items'] is! List) {
      throw const FormatException('items missing or not a list');
    }
    final rawItems = _items(data);
    final items = <OrderSummary>[];
    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        final order = _parseOrder(raw);
        // Must never surface on-hold requests (ClientHomeCubit).
        if (order.status.isOnHold) continue;
        // Tabs must ACTUALLY filter; linger showed terminals under all tabs (run-22 P1-B).
        if (order.status.tab != tab) continue;
        items.add(order);
      }
    }
    return OrderPage(
      items: items,
      page: requestedPage,
      hasMore: rawItems.length >= pageSize,
    );
  }

  static OrderSummary _parseOrder(Map<String, dynamic> json) {
    final amount = json['amount'];
    final pickup = json['pickup'];
    final dropoff = json['dropoff'];
    return OrderSummary(
      id: _str(json['id']) ?? '',
      createdAt:
          ServerTime.parse(_str(json['createdAt'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pickupAddress: pickup is Map<String, dynamic>
          ? (_str(pickup['address']) ?? '')
          : (_str(json['pickupAddress']) ?? ''),
      dropoffAddress: dropoff is Map<String, dynamic>
          ? (_str(dropoff['address']) ?? '')
          : (_str(json['dropoffAddress']) ?? ''),
      status: OrderRequestStatus.parse(_str(json['status'])),
      tier: OrderTier.parse(_str(json['tier']) ?? _str(json['tierId'])),
      // Wire drift (run-22 P1-A): live gateway sends multiple amount formats.
      amountMinor: switch (amount) {
        final num flat => (flat * 100).round(),
        {'minorUnits': final num minor} => minor.round(),
        {'value': final num value} => (value * 100).round(),
        _ => null,
      },
      // `currency` is non-nullable on OrderSummary, so 'USD' stays the model
      // fallback here; nullability is filed for WP-9.
      currency: amount is Map<String, dynamic>
          ? (_str(amount['currency']) ?? 'USD')
          : (_str(json['currency']) ?? 'USD'),
    );
  }

  /// Null-safe read: the gateway has shipped numeric ids, and an `as String?`
  /// on one throws TypeError rather than yielding null.
  static String? _str(Object? value) => value is String ? value : null;

  static List<dynamic> _items(Object? data) {
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return data['items'] as List;
    }
    return const <dynamic>[];
  }
}
