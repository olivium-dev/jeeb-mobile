/// Result of broadcasting an order-chat request (JM-025 AC1).
///
/// Carries the [requestId] the waiting screen routes to. [notifiedCount] is the
/// number of nearby Jeebers the broadcast reached (drives the waiting screen's
/// count vs no-coverage variant, JM-026) — the screen does not depend on it for
/// navigation, but it is surfaced so a future caller could branch on coverage.
class OrderBroadcastResult {
  const OrderBroadcastResult({
    required this.requestId,
    this.notifiedCount = 0,
  });

  final String requestId;
  final int notifiedCount;
}

/// Failure surface for the compose→broadcast step. The screen keeps the user in
/// the composer on failure (the draft is preserved) and surfaces a soft error.
enum OrderBroadcastFailure { network, badRequest, unknown }

class OrderBroadcastException implements Exception {
  const OrderBroadcastException(this.failure, [this.message]);
  final OrderBroadcastFailure failure;
  final String? message;
}

/// Broadcasts an order-chat request to nearby Jeebers (D83, JM-025 AC1 / JM-026).
///
/// PURE domain contract — no Dio/Flutter/GetIt imports. The order-chat compose
/// state fires this on the FIRST message; the request then transitions from
/// compose to `pending`/broadcasting and the app routes to `waiting-no-coverage`.
abstract class OrderBroadcastService {
  /// Broadcast the request behind [conversationId] (a conversation id or, in
  /// the fresh-compose case, a request id). [tier] + [origin] are forwarded to
  /// matching; both may be empty when the upstream create-leg already pinned
  /// them on the request row. Throws [OrderBroadcastException] on failure.
  Future<OrderBroadcastResult> broadcast({
    required String conversationId,
    required String requestId,
    String tier,
  });
}
