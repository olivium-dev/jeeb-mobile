// PURE Dart — no Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1).
//
// JM-026 — Waiting / No-Coverage state [D48, D69].
//
// Domain snapshot of a broadcast (pre-accept) request as the waiting screen
// needs it: how many Jeebers were notified, the ANCHOR PAIR that drives the
// countdown, and whether offers have started arriving (the live transition to
// the review-offers CTA). The screen branches on this model alone; it never
// touches the transport layer.
//
// P7 clean break: the countdown is derived from a SERVER-RELATIVE remaining
// value paired with the DEVICE instant it was received — never from a server
// absolute. Device clock skew therefore cannot shift the countdown, and there
// is no client-side fallback window to fabricate one.

import 'package:equatable/equatable.dart';

/// Lifecycle of the request as the waiting screen reads it.
///
/// The waiting surface distinguishes its two live phases from the server-owned
/// outcomes that end waiting. The terminal variants let the UI show an honest
/// next state instead of leaving a dead request under a live countdown.
enum WaitingRequestPhase {
  broadcasting,
  offersArrived,
  matched,
  cancelled,
  expired,
  closed,
}

extension WaitingRequestPhaseX on WaitingRequestPhase {
  /// Whether this phase has left the pre-accept waiting flow.
  bool get isTerminal => switch (this) {
    WaitingRequestPhase.broadcasting ||
    WaitingRequestPhase.offersArrived => false,
    WaitingRequestPhase.matched ||
    WaitingRequestPhase.cancelled ||
    WaitingRequestPhase.expired ||
    WaitingRequestPhase.closed => true,
  };
}

/// Immutable snapshot of the pre-accept request driving the waiting screen.
class WaitingRequest extends Equatable {
  const WaitingRequest({
    required this.requestId,
    required this.phase,
    required this.notifiedCount,
    required this.offerCount,
    required this.receivedAt,
    this.remainingAtReceipt,
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

  /// Device-clock instant at which this snapshot was parsed. Together with
  /// [remainingAtReceipt] this is the ONLY input the countdown derives from.
  final DateTime receivedAt;

  /// Server-authoritative time left when the payload was received.
  ///
  /// NULL means the server says NO COUNTDOWN APPLIES to this row (accepted,
  /// scheduled, terminal). It NEVER means "the field was missing": a live row
  /// without it is a contract violation that throws in the repository and never
  /// reaches this constructor. There is no fallback window.
  final Duration? remainingAtReceipt;

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

  /// Countdown deadline IN THE DEVICE CLOCK DOMAIN. Deliberately derived from a
  /// RELATIVE server value, never parsed from a server absolute, so device clock
  /// skew cannot corrupt it. Do not compare to a server timestamp.
  DateTime? get deadline {
    final remaining = remainingAtReceipt;
    return remaining == null ? null : receivedAt.add(remaining);
  }

  /// Copies the snapshot forward. It deliberately exposes NO way to change
  /// [receivedAt] / [remainingAtReceipt]: the anchor pair is carried verbatim,
  /// which is the structural guard against the countdown resetting to full when
  /// an offer lands (P7 T6).
  WaitingRequest copyWith({
    WaitingRequestPhase? phase,
    int? notifiedCount,
    int? offerCount,
    String? displayId,
    String? tier,
    String? title,
  }) => WaitingRequest(
    requestId: requestId,
    phase: phase ?? this.phase,
    notifiedCount: notifiedCount ?? this.notifiedCount,
    offerCount: offerCount ?? this.offerCount,
    receivedAt: receivedAt, // anchor NEVER re-stamped here
    remainingAtReceipt: remainingAtReceipt, // carried as a PAIR
    displayId: displayId ?? this.displayId,
    tier: tier ?? this.tier,
    title: title ?? this.title,
  );

  @override
  List<Object?> get props => [
    requestId,
    phase,
    notifiedCount,
    offerCount,
    receivedAt,
    remainingAtReceipt,
    displayId,
    tier,
    title,
  ];
}
