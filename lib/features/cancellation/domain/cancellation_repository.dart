import 'cancellation_result.dart';

/// Abstract repository for cancellation (posts to /v1/deliveries/{id}/cancel).
abstract class CancellationRepository {
  /// Submits cancellation; [reason] required (Jeeber), [otherDetails] for reason=='other'.
  /// Throws [CancellationTooLateException] (HTTP 409) or [CancellationException] (other).
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  });
}

/// Thrown when delivery is in a terminal / post-pickup state.
class CancellationTooLateException implements Exception {
  const CancellationTooLateException();
}

/// Generic cancellation failure (network / 4xx / 5xx).
class CancellationException implements Exception {
  const CancellationException(this.message);

  final String message;
}
