import 'order_summary.dart';

abstract class OrderRepository {
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  });
}

class OrderRepositoryException implements Exception {
  const OrderRepositoryException(this.kind, [this.cause]);

  final OrderRepositoryErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'OrderRepositoryException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum OrderRepositoryErrorKind { network, server, parse }
