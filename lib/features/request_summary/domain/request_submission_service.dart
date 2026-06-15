import 'request_draft.dart';

/// Domain contract for submitting an assembled delivery request.
///
/// Endpoint verified against the gateway-shaped mock (Mockoon :3055,
/// `useMockPrefixes=false`):
///   POST /requests
///   body: { description, transcription?, audioUrl?, photos[], tierId?,
///           pickupLocation{lat,lng}?, dropoffLocation{lat,lng}?,
///           pickupAddress?, dropoffAddress? }
///   201 → { id, status, ... }  on success; the created request id is `id`.
///   4xx → invalid input / rejected
///   5xx / timeout → transient server / network failure
///
/// Returns the server-minted request id on success; throws
/// [RequestSubmissionException] on failure.
abstract class RequestSubmissionService {
  Future<String> submit(RequestDraft draft);
}

/// Typed failure cases for request submission.
enum RequestSubmissionFailure {
  /// The gateway rejected the payload (4xx other than auth/conflict).
  invalidInput,

  /// Network unreachable / timed out — safe to retry.
  network,

  /// Any other server-side failure (5xx, or an unexpected response shape).
  server,
}

class RequestSubmissionException implements Exception {
  const RequestSubmissionException(this.failure, [this.message]);

  final RequestSubmissionFailure failure;
  final String? message;

  @override
  String toString() =>
      'RequestSubmissionException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}
