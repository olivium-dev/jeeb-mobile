// PURE Dart — no Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1).
//
// JM-026 — Waiting / No-Coverage state [D48, D69].
//
// Domain snapshot of a broadcast (pre-accept) request as the waiting screen
// needs it: how many Jeebers were notified, the broadcast deadline that drives
// the countdown, and whether offers have started arriving (the live transition
// to the review-offers CTA). The screen branches on this model alone; it never
// touches the transport layer.

import 'package:equatable/equatable.dart';

/// Lifecycle of the request as the waiting screen reads it.
///
/// Only the pre-accept states matter here: a request is either still
/// `broadcasting` (waiting for the first offer), has `offersArrived` (at least
/// one bid is in — show the review CTA), or is `closed` (accepted/cancelled/
/// expired — the screen has nothing more to wait for).
enum WaitingRequestPhase { broadcasting, offersArrived, closed }

/// Immutable snapshot of the pre-accept request driving the waiting screen.
class WaitingRequest extends Equatable {
  const WaitingRequest({
    required this.requestId,
    required this.phase,
    required this.notifiedCount,
    required this.offerCount,
    this.broadcastExpiresAt,
    this.displayId,
    this.tier,
    this.title,
  });

  /// Stable request id (e.g. `req-client-001-pending`).
  final String requestId;

  /// Coarse phase the screen branches on.
  final WaitingRequestPhase phase;

  /// Informational count of nearby Jeebers the gateway claims to have notified.
  /// NOTE: jeebers discover requests by pulling `GET /v1/jeebers/me/feed`, not
  /// via a push-notify counter, so the gateway never populates this — it is
  /// effectively always `0`. It therefore MUST NOT gate any no-coverage / "no
  /// offers" UI state (see BUG-4 / JM-026 false-no-coverage). It is kept purely
  /// as informational copy ("Notified N nearby Jeebers") when `> 0`.
  final int notifiedCount;

  /// Number of offers received so far. `> 0` flips the screen to the
  /// review-offers CTA (AC2).
  final int offerCount;

  /// Server-provided broadcast deadline. Drives the countdown; `null` when the
  /// gateway omits it (the cubit then falls back to a local window so the
  /// `waiting_countdown` still renders).
  final DateTime? broadcastExpiresAt;

  /// Human-facing reference (e.g. `ORD-501001`) for the header.
  final String? displayId;

  /// Tier slug (e.g. `express`) — shown so the user can decide whether to
  /// re-target (D48).
  final String? tier;

  /// Short request title.
  final String? title;

  /// True once at least one offer has arrived.
  bool get hasOffers =>
      offerCount > 0 || phase == WaitingRequestPhase.offersArrived;

  @override
  List<Object?> get props => [
        requestId,
        phase,
        notifiedCount,
        offerCount,
        broadcastExpiresAt,
        displayId,
        tier,
        title,
      ];
}
