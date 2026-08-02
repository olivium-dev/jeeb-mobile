/// Result of broadcasting an order-chat request. [notifiedCount] drives waiting screen
/// variant selection; screen routes via [requestId].
class OrderBroadcastResult {
  const OrderBroadcastResult({
    required this.requestId,
    this.notifiedCount = 0,
  });

  final String requestId;
  final int notifiedCount;
}

/// Failure surface for compose→broadcast step. Screen keeps user in composer.
enum OrderBroadcastFailure { network, badRequest, unknown }

class OrderBroadcastException implements Exception {
  const OrderBroadcastException(this.failure, [this.message]);
  final OrderBroadcastFailure failure;
  final String? message;
}

/// Broadcasts order-chat request to nearby Jeebers. PURE domain contract (no Dio/Flutter/GetIt).
abstract class OrderBroadcastService {
  /// Broadcast request behind [conversationId] (conversation id or fresh-compose request id).
  /// [tier] + [origin] forwarded to matching (may be empty if upstream create-leg pinned them).
  Future<OrderBroadcastResult> broadcast({
    required String conversationId,
    required String requestId,
    String tier,
  });
}
