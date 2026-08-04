import 'order_summary.dart';

enum OrderSummaryFailure {
  network,

  notFound,

  unknown,
}

abstract class OrderSummaryRepository {
  Future<OrderSummary> fetchSummary(String deliveryId);
}

class OrderSummaryRepositoryException implements Exception {
  const OrderSummaryRepositoryException(this.failure, [this.message]);
  final OrderSummaryFailure failure;
  final String? message;

  @override
  String toString() =>
      'OrderSummaryRepositoryException($failure, $message)';
}
