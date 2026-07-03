// PURE Dart — no Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1).
//
// JM-030 — Cancel Request Confirm sheet (pre-accept, free) [D69].
//
// This is the PRE-ACCEPT cancel path. It is deliberately distinct from
// `lib/features/cancellation/` (the post-accept reason picker that may charge a
// fee — 20_GAP_MAP reconciliation note 7 explicitly forbids reusing it). Before
// an offer is accepted there is no Jeeber, no locked price, and nothing charged:
// cancelling a still-pending request is free (D69). The terminal destination is
// `customer-orders-home` (the role-aware shell Requests tab).

/// Classified failure the cubit translates into copy.
///
/// sprint-009 cycle-4: the gateway now exposes a request-keyed cancel
/// (`DELETE /v1/requests/{id}`) with canonical typed semantics, so failures
/// are REAL and must surface — the mock-era "swallow everything, pretend
/// success" behaviour is gone. A cancel that did not happen server-side is
/// never reported as a success.
enum CancelRequestFailure {
  /// Connection/timeout — retryable. The sheet stays open with the network
  /// copy so the user can retry confirm (we cannot know whether the request
  /// was released).
  network,

  /// 409 — the request has advanced past the cancellable window (an offer
  /// was accepted / delivery started). Surfaced as "this request can no
  /// longer be cancelled".
  conflict,

  /// 404 — the gateway does not know this request id. Surfaced; the local
  /// pending row must NOT be silently released on the strength of a miss.
  notFound,

  /// 403 — the caller does not own the request. Surfaced.
  forbidden,

  /// Anything else (5xx, malformed body). Surfaced with generic copy.
  unknown,
}

/// Read/write contract for cancelling a *pre-accept* request.
///
/// Implementations call the gateway in production and an in-memory fake in
/// tests. The cubit depends only on this abstract type.
abstract class CancelRequestRepository {
  /// Cancels the pre-accept [requestId] via the request-keyed gateway cancel
  /// (`DELETE /v1/requests/{id}`; requestId == deliveryId convention).
  /// Returns normally ONLY when the server confirmed the cancel.
  ///
  /// Throws [CancelRequestException] with the typed [CancelRequestFailure]
  /// otherwise — including 409/404/403 and unexpected server errors. Nothing
  /// is swallowed: the UI decides how each failure surfaces.
  Future<void> cancelRequest({required String requestId});
}

/// Typed exception the repository raises so the cubit maps cleanly without
/// peeking at the underlying transport.
class CancelRequestException implements Exception {
  const CancelRequestException(this.failure, [this.message]);

  final CancelRequestFailure failure;
  final String? message;

  @override
  String toString() => 'CancelRequestException($failure, $message)';
}
