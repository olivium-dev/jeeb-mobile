/// One Jeeber considered by the canonical gateway matching run.
class OrderMatchingCandidate {
  const OrderMatchingCandidate({
    required this.userId,
    required this.vehicleType,
    required this.distanceKm,
    required this.rating,
  });

  final String userId;
  final String vehicleType;
  final double distanceKm;
  final double rating;
}

/// Typed result of the canonical gateway `POST /matching/run` mutation.
class OrderBroadcastResult {
  const OrderBroadcastResult({
    required this.requestId,
    this.notifiedCount = 0,
    this.candidateCount = 0,
    this.candidates = const [],
    this.tierId = '',
    this.radiusKm = 0,
    this.elapsedMs = 0,
  });

  final String requestId;
  final int notifiedCount;
  final int candidateCount;
  final List<OrderMatchingCandidate> candidates;
  final String tierId;
  final double radiusKm;
  final int elapsedMs;
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
  /// Runs matching once for the persisted [requestId].
  Future<OrderBroadcastResult> broadcast({required String requestId});
}
