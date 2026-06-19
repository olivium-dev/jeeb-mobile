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

  /// Number of nearby Jeebers the matching service notified. `0` drives the
  /// no-coverage variant (63 §2.6 `waiting_no_coverage_state`).
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

  /// True when zero Jeebers were notified — the no-coverage variant.
  bool get hasNoCoverage => notifiedCount <= 0;

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
