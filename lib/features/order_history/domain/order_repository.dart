import '../../../core/network/app_failure.dart';
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
  const OrderRepositoryException(this.kind, [this.cause, this.failure]);

  final OrderRepositoryErrorKind kind;
  final Object? cause;

  /// The classified failure; null on a legacy throw site.
  final AppFailure? failure;

  @override
  String toString() =>
      'OrderRepositoryException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum OrderRepositoryErrorKind { network, server, parse }
