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

/// Classified failure the cubit translates into copy. The pre-accept cancel
/// surfaces almost nothing to the user (D69: it is free and always allowed),
/// so the only failure that must block the happy path is a hard transport
/// error; everything else degrades to "cancelled" (see [DioCancelRequestRepository]).
enum CancelRequestFailure {
  /// Connection/timeout — the only failure that keeps the sheet open with a
  /// retry affordance, because we cannot confirm the request was released.
  network,

  /// Anything else (5xx, malformed body). Treated as a soft failure.
  unknown,
}

/// Read/write contract for cancelling a *pre-accept* request.
///
/// Implementations call the gateway in production and an in-memory fake in
/// tests. The cubit depends only on this abstract type.
abstract class CancelRequestRepository {
  /// Cancels the pre-accept [requestId]. Returns normally on success.
  ///
  /// CONTRACT NOTE (flagged as a gap — see handoff): the mock's
  /// `POST /v1/delivery/cancel` is keyed by `deliveryId` and enforces the SM-1
  /// delivery state machine, but a *pending* request has **no delivery yet**
  /// (a delivery is only created when an offer is accepted). The Dio impl
  /// therefore posts the request id, and treats a 404 `not_found` /
  /// 422 `transition_not_allowed` as a benign "nothing to cancel server-side"
  /// — the pre-accept cancel is free and locally authoritative (D69). A real
  /// `POST /requests/:id/cancel` (or a request-aware cancel) is the proper
  /// backend contract; tracked as a gap.
  ///
  /// Throws [CancelRequestException] only on a hard transport failure
  /// ([CancelRequestFailure.network]) where we cannot establish the request
  /// was released.
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
