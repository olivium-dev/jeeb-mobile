enum DisputeState { open, resolved, unknown }

enum DisputeOutcome {
  refund,

  penalty,

  dismissed,

  other,

  none,
}

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

  final String? reason;

  final String? comment;

  final int photoCount;

  final bool hasVoice;

  final bool hasChatSnapshot;

  final int? chatMessageCount;

  final int timelineCount;

  bool get hasAny =>
      (reason != null && reason!.isNotEmpty) ||
      (comment != null && comment!.isNotEmpty) ||
      photoCount > 0 ||
      hasVoice ||
      hasChatSnapshot ||
      timelineCount > 0;
}

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

  final DisputeOutcome outcome;

  final String? resolution;

  final String? note;

  final double? refundAmount;
  final String? currency;

  final String? orderRef;

  final String? conversationRef;

  final String? createdAt;
  final String? resolvedAt;

  final DisputeEvidenceSummary evidence;

  bool get isResolved => state == DisputeState.resolved;

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

abstract class DisputeStatusRepository {
  Future<DisputeStatus> fetchDispute(String disputeId);
}
