// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Dispute open + evidence domain contract (JM-060, blueprint `dispute-open-evidence`).
//
// Repointed from the dead T-MOB-022 `POST /v1/deliveries/{id}/escalate` (which
// never existed on :4010) to the LIVE compliment-service:
//   POST /v1/disputes
//     body: { deliveryId, reason, comment?, photos:[…], voiceUrl?, evidence:{…} }
//     → 201 { id, status:"open", … }  (the `id` is the dispute id used to route
//        to `dispute-status` /disputes/:id, JM-065)
//
// Evidence auto-attach (D53): the chat snapshot URL + the GPS/status timeline
// are gathered from the chat-service snapshot + delivery-service status and
// posted with the dispute, and shown read-only on the screen before submit.
//
// Decisions: D19 (dispute lifecycle), D53 (evidence: photos + voice + auto-
// attached chat & GPS/status snapshot), D2 (refund/penalty outcome), D54, D76
// (support escalation). Mock: `POST /compliment-service/v1/disputes`,
// `GET .../conversations/:conversationId/snapshot` (42_GUARDRAILS_MOCK §4).

/// Auto-attached evidence (D53) gathered for a dispute: the immutable chat
/// snapshot + the GPS/status timeline at the moment the dispute is opened.
/// Resolved by [EscalateRepository.fetchEvidence] and posted with the dispute.
class EscalateEvidence {
  const EscalateEvidence({
    this.chatSnapshotUrl,
    this.chatMessageCount,
    this.timeline = const <EscalateTimelineEntry>[],
  });

  /// CDN URL of the immutable conversation snapshot (D53). Null when the
  /// originating order has no conversation (or the fetch degraded gracefully).
  final String? chatSnapshotUrl;

  /// Number of messages captured in the snapshot. Null when unknown.
  final int? chatMessageCount;

  /// The GPS/status timeline (Ordered → Picked → In Transit → Delivered, D70)
  /// at dispute-open time. Empty when no delivery status is resolvable.
  final List<EscalateTimelineEntry> timeline;

  bool get hasChatSnapshot => (chatSnapshotUrl ?? '').isNotEmpty;
  bool get hasTimeline => timeline.isNotEmpty;
  bool get isEmpty => !hasChatSnapshot && !hasTimeline;

  static const EscalateEvidence empty = EscalateEvidence();
}

/// A single GPS/status timeline entry (D53 snapshot). The status is the raw
/// wire status string (`Ordered`/`Picked`/`InTransit`/`AtDoor`/`Done`); the UI
/// maps it to a localized step label.
class EscalateTimelineEntry {
  const EscalateTimelineEntry({required this.status, this.at});

  /// Raw delivery status (the SM-1 wire casing).
  final String status;

  /// ISO-8601 timestamp the status was reached, when the row carries one.
  final String? at;
}

abstract class EscalateRepository {
  /// Resolve the auto-attached evidence (D53) for [deliveryId]: the chat
  /// snapshot + GPS/status timeline. Never throws — a degraded fetch returns
  /// [EscalateEvidence.empty] so opening a dispute is never blocked by a
  /// missing snapshot.
  Future<EscalateEvidence> fetchEvidence({required String deliveryId});

  /// Open a dispute (`POST /v1/disputes`). Returns the created dispute so the
  /// screen can route to `dispute-status` with its id. Throws
  /// [EscalateException] on transport/contract failure.
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths,
    String? voicePath,
    EscalateEvidence evidence,
  });
}

enum EscalateReason { damaged, wrongItem, noShow, fraud, abuse, other }

class EscalateResult {
  const EscalateResult({required this.caseId, required this.status});

  factory EscalateResult.fromJson(Map<String, dynamic> json) {
    return EscalateResult(
      caseId: json['id'] as String? ??
          json['disputeId'] as String? ??
          json['caseId'] as String? ??
          json['case_id'] as String? ??
          '',
      status: json['status'] as String? ?? 'open',
    );
  }

  /// The dispute id (`id` on the compliment-service row). Used to route to
  /// `dispute-status` (/disputes/:id, JM-065).
  final String caseId;
  final String status;
}

class EscalateException implements Exception {
  const EscalateException(this.kind, [this.cause]);

  final EscalateErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'EscalateException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum EscalateErrorKind { network, server, alreadyOpen, notFound }
