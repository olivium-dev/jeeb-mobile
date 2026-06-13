import 'cancellation_result.dart';

/// Abstract repository for the cancellation flow (T-MOB-024).
///
/// Backed by POST `/v1/deliveries/{id}/cancel`.
abstract class CancellationRepository {
  /// Submits a cancellation request for [deliveryId].
  ///
  /// [reason] is required for Jeeber callers; optional for clients.
  /// [otherDetails] carries free-text when reason == 'other'.
  ///
  /// Throws [CancellationRateLimitException] on HTTP 429.
  /// Throws [CancellationTooLateException] on HTTP 409.
  /// Throws [CancellationException] on other failures.
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  });
}

/// Thrown when the server returns 429 (weekly rate limit exceeded).
class CancellationRateLimitException implements Exception {
  const CancellationRateLimitException({this.retryAfter});

  /// The moment the limit resets (ISO-8601 from `retryAfter` field).
  final DateTime? retryAfter;
}

/// Thrown when the delivery is already in a terminal / post-pickup state.
class CancellationTooLateException implements Exception {
  const CancellationTooLateException();
}

/// Generic cancellation failure (network / 4xx / 5xx).
class CancellationException implements Exception {
  const CancellationException(this.message);

  final String message;
}
