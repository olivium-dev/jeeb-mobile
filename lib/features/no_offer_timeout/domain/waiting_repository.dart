// PURE Dart — no Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1).
//
// JM-026 — Waiting / No-Coverage state [D48, D69].

import 'waiting_request.dart';

/// Classified failure the cubit translates into copy.
enum WaitingFailure {
  /// Connection/timeout — the screen shows a retry affordance.
  network,

  /// The request id resolves to nothing server-side (404). Treated as a
  /// terminal "nothing to wait for" — the screen surfaces a closed state.
  notFound,

  /// Anything else (5xx, malformed body).
  unknown,

  /// The gateway answered 200 but the payload violates the offer-wait contract
  /// (e.g. a live pending row with no `offerDeadlineInSeconds`). Retrying cannot
  /// help — the client stops polling and surfaces a backend-contract error, it
  /// NEVER manufactures a countdown.
  contractViolation,
}

/// Read contract for the pre-accept waiting screen.
///
/// Implementations call the gateway in production ([DioWaitingRepository]) and
/// an in-memory fake in tests. The cubit depends only on this abstract type.
abstract class WaitingRepository {
  /// Fetches the current pre-accept snapshot for [requestId].
  ///
  /// Sources (30_BACKLOG JM-026 · 42_GUARDRAILS_MOCK §1.2):
  ///   GET /v1/requests/:requestId  → status + notifiedCount +
  ///                                  offerDeadlineInSeconds
  ///   GET /v1/offers?requestId=:id → offerCount (offers-arrived signal)
  ///
  /// Throws [WaitingException] on a hard failure so the cubit maps cleanly
  /// without peeking at the transport.
  ///
  /// NOTE: this is the *combined* read used by polling. The cold-load path uses
  /// [fetchRequest] + [fetchOfferCount] so the broadcast-state signature ids
  /// (`waiting_notified_count` / `waiting_countdown`) paint as soon as the
  /// request row resolves, WITHOUT waiting on the offers read (JM-026 AC1).
  Future<WaitingRequest> fetchWaiting(String requestId);

  /// Reads ONLY the request row (status + notifiedCount +
  /// `offerDeadlineInSeconds`). The
  /// returned [WaitingRequest] carries `offerCount = 0` / `phase` derived from
  /// the row's own status alone — the offers signal is layered on separately
  /// via [fetchOfferCount]. This is the first leg of the cold load so the
  /// broadcast header (`waiting_notified_count`) is never blocked behind the
  /// offers GET (JM-026 AC1: count + countdown render up-front).
  Future<WaitingRequest> fetchRequest(String requestId);

  /// Reads the authoritative offer count for [requestId] (the offers-arrived
  /// signal, JM-026 AC2). Best-effort: implementations swallow transient
  /// transport failures and return `0` so the offers read never tears down the
  /// already-painted broadcast state. The optional [fallback] lets callers pass
  /// the request row's denormalised count when the dedicated read is
  /// unavailable.
  Future<int> fetchOfferCount(String requestId, {int fallback = 0});
}

/// Typed exception the repository raises.
class WaitingException implements Exception {
  const WaitingException(this.failure, [this.message]);

  final WaitingFailure failure;
  final String? message;

  @override
  String toString() => 'WaitingException($failure, $message)';
}
