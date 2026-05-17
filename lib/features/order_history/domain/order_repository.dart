import 'order_summary.dart';

/// Contract the [OrderHistoryCubit] depends on. Implementations live in
/// the `data/` layer (Dio against the real gateway, or an in-memory fake
/// for tests).
///
/// The cubit only ever asks for one page at a time and concatenates the
/// results client-side; the repository is intentionally stateless so two
/// cubits (e.g. tab + a future detail screen) can share it safely.
abstract class OrderRepository {
  /// Fetches a single page of orders.
  ///
  /// - [tab] determines the `status` filter sent to the gateway.
  /// - [page] is 1-based to match the gateway pagination convention.
  /// - [range] is optional; when both ends are null no date filter is sent.
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  });
}

/// Network or parse failures surfaced by the repository. The cubit maps
/// these to user-visible error states; nothing else in the app should
/// catch them.
class OrderRepositoryException implements Exception {
  const OrderRepositoryException(this.kind, [this.cause]);

  final OrderRepositoryErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'OrderRepositoryException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum OrderRepositoryErrorKind { network, server, parse }
