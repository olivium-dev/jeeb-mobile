import 'order_summary.dart';

/// Classified failure surfaces the cubit maps to copy, so the UI never sees a
/// raw `DioException`.
enum OrderSummaryFailure {
  /// Connection / timeout — the device is offline or the gateway is unreachable.
  network,

  /// The delivery/order could not be found (404). The accepted order vanished
  /// or the id is wrong; the pinned widget cannot render.
  notFound,

  /// Any other / malformed-response failure.
  unknown,
}

/// Read-side contract for the order-summary surface (JM-031).
///
/// Implementations call the gateway in production
/// (`GET /v1/delivery/:id` (+ best-effort `/v1/requests/:id`, `/v1/offers`,
/// `/users/:id`)) and an in-memory fake during tests.
abstract class OrderSummaryRepository {
  /// Fetches the pinned [OrderSummary] for an accepted [deliveryId]. Throws an
  /// [OrderSummaryRepositoryException] tagged with the canonical
  /// [OrderSummaryFailure] on the hard (delivery) fetch failing; secondary
  /// enrichment fetches (rating / ETA) degrade silently.
  Future<OrderSummary> fetchSummary(String deliveryId);
}

/// Typed exception the repository raises so the cubit can map cleanly without
/// peeking at the underlying transport.
class OrderSummaryRepositoryException implements Exception {
  const OrderSummaryRepositoryException(this.failure, [this.message]);
  final OrderSummaryFailure failure;
  final String? message;

  @override
  String toString() =>
      'OrderSummaryRepositoryException($failure, $message)';
}
