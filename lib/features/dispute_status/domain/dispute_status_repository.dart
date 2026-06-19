// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Dispute-status domain contract (JM-065). The compliment-service dispute
// endpoints are LIVE on :4010 (`GET /v1/disputes/:disputeId`,
// 42_GUARDRAILS_MOCK §4 "mock-ready"), so the DI default is the real
// `DioDisputeStatusRepository`. Decisions: D2 (outcome refund/penalty), D19,
// D53 (evidence snapshot), D76 (support escalation).

/// The lifecycle state of a dispute (JM-065). `open` while under review;
/// `resolved` once the back-office decides (carrying a refund/penalty outcome).
enum DisputeState { open, resolved, unknown }

/// The back-office outcome class once a dispute is resolved (D2). The wire
/// `resolution` string maps onto this so the screen can render the correct
/// outcome copy + sign without re-parsing free text downstream.
enum DisputeOutcome {
  /// A refund was applied to the customer (D2).
  refund,

  /// A penalty was applied to the jeeber (D2).
  penalty,

  /// The dispute was dismissed / no action taken.
  dismissed,

  /// Resolved with an outcome the contract doesn't enumerate (render the raw
  /// note rather than a typed line).
  other,

  /// Still open — no outcome yet.
  none,
}

/// An immutable summary of the evidence auto-attached to the dispute at open
/// time (D53): the originating reason, a free-text comment, the photo/voice
/// counts, and the auto-attached chat-snapshot + GPS/status timeline. The
/// status screen renders this as a read-only summary — it does NOT re-upload or
/// edit evidence (that is dispute-open-evidence, JM-060).
class DisputeEvidenceSummary {
  const DisputeEvidenceSummary({
    this.reason,
    this.comment,
    this.photoCount = 0,
    this.hasVoice = false,
    this.hasChatSnapshot = false,
    this.chatMessageCount,
    this.timelineCount = 0,
  });

  static const DisputeEvidenceSummary empty = DisputeEvidenceSummary();

  /// The originating reason code (`damaged` / `wrong_item` / `no_show` / …).
  final String? reason;

  /// The customer's free-text comment, if any.
  final String? comment;

  /// Number of photos attached (≤5, D53).
  final int photoCount;

  /// Whether a voice note was attached (D53).
  final bool hasVoice;

  /// Whether the chat thread was auto-attached as a snapshot (D53).
  final bool hasChatSnapshot;

  /// Count of messages in the attached chat snapshot, if surfaced.
  final int? chatMessageCount;

  /// Number of GPS/status timeline entries auto-attached (D53).
  final int timelineCount;

  /// True when the dispute carries at least one piece of evidence to summarise.
  bool get hasAny =>
      (reason != null && reason!.isNotEmpty) ||
      (comment != null && comment!.isNotEmpty) ||
      photoCount > 0 ||
      hasVoice ||
      hasChatSnapshot ||
      timelineCount > 0;
}

/// A dispute snapshot for the status screen (W3m disputes contract).
class DisputeStatus {
  const DisputeStatus({
    required this.id,
    required this.state,
    this.outcome = DisputeOutcome.none,
    this.resolution,
    this.note,
    this.refundAmount,
    this.currency,
    this.orderRef,
    this.conversationRef,
    this.createdAt,
    this.resolvedAt,
    this.evidence = DisputeEvidenceSummary.empty,
  });

  final String id;
  final DisputeState state;

  /// The typed back-office outcome (D2), derived from [resolution].
  final DisputeOutcome outcome;

  /// The raw back-office outcome string (refund / penalty / dismissed), D2.
  final String? resolution;

  /// Free-text outcome note.
  final String? note;

  /// The refunded/penalty amount when the outcome carries one (D2).
  final double? refundAmount;
  final String? currency;

  /// The originating order/delivery reference → order-chat.
  final String? orderRef;

  /// The conversation id (when distinct from [orderRef]) used to address the
  /// chat thread on the back edge.
  final String? conversationRef;

  final String? createdAt;
  final String? resolvedAt;

  /// The auto-attached evidence summary (D53).
  final DisputeEvidenceSummary evidence;

  /// True once the back-office has resolved the dispute.
  bool get isResolved => state == DisputeState.resolved;

  /// The best reference to address the order-chat thread on the back edge:
  /// the conversation id if present, else the order/delivery ref.
  String? get chatRef {
    final c = conversationRef;
    if (c != null && c.isNotEmpty) return c;
    final o = orderRef;
    if (o != null && o.isNotEmpty) return o;
    return null;
  }
}

enum DisputeStatusFailure { network, notFound, unauthorized, unknown }

class DisputeStatusRepositoryException implements Exception {
  const DisputeStatusRepositoryException(this.failure, [this.message]);

  final DisputeStatusFailure failure;
  final String? message;

  @override
  String toString() => 'DisputeStatusRepositoryException($failure, $message)';
}

/// Domain contract for the dispute-status screen (JM-065).
abstract class DisputeStatusRepository {
  /// Fetch a single dispute by id. Throws [DisputeStatusRepositoryException] on
  /// failure.
  Future<DisputeStatus> fetchDispute(String disputeId);
}
