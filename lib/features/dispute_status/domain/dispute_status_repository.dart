enum DisputeState {
  pending,
  fixed,
  closed,

  /// Backward-compatible fixture aliases. Gateway responses are normalized to
  /// the three canonical values above.
  open,
  resolved,
  unknown,
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
    this.completeness = EvidenceCompleteness.none,
    this.attachments = const <DisputeEvidenceAttachment>[],
    this.missingSources = const <String>[],
  });

  static const DisputeEvidenceSummary empty = DisputeEvidenceSummary();

  final String? reason;

  final String? comment;

  final int photoCount;

  final bool hasVoice;

  final bool hasChatSnapshot;

  final int? chatMessageCount;

  final int timelineCount;
  final EvidenceCompleteness completeness;
  final List<DisputeEvidenceAttachment> attachments;
  final List<String> missingSources;

  bool get isPartial =>
      completeness == EvidenceCompleteness.partial ||
      missingSources.isNotEmpty ||
      attachments.any((item) => item.status == EvidenceAttachmentStatus.failed);

  bool get hasAny =>
      (reason != null && reason!.isNotEmpty) ||
      (comment != null && comment!.isNotEmpty) ||
      photoCount > 0 ||
      hasVoice ||
      hasChatSnapshot ||
      timelineCount > 0 ||
      attachments.isNotEmpty ||
      isPartial;
}

enum EvidenceCompleteness { complete, partial, none, unknown }

enum EvidenceAttachmentStatus { uploaded, failed, pending, unknown }

class DisputeEvidenceAttachment {
  const DisputeEvidenceAttachment({
    required this.id,
    required this.kind,
    required this.status,
    this.fileName,
    this.objectRef,
  });

  final String id;
  final String kind;
  final EvidenceAttachmentStatus status;
  final String? fileName;
  final String? objectRef;
}

class DisputeStatusHistoryEntry {
  const DisputeStatusHistoryEntry({required this.status, this.at, this.note});

  final DisputeState status;
  final String? at;
  final String? note;
}

class DisputeStatus {
  const DisputeStatus({
    required this.id,
    required this.state,
    this.note,
    this.orderRef,
    this.conversationRef,
    this.createdAt,
    this.resolvedAt,
    this.evidence = DisputeEvidenceSummary.empty,
    this.statusHistory = const <DisputeStatusHistoryEntry>[],
    this.version,
  });

  final String id;
  final DisputeState state;

  final String? note;

  final String? orderRef;

  final String? conversationRef;

  final String? createdAt;
  final String? resolvedAt;

  final DisputeEvidenceSummary evidence;
  final List<DisputeStatusHistoryEntry> statusHistory;
  final int? version;

  DisputeState get canonicalState => switch (state) {
    DisputeState.open => DisputeState.pending,
    DisputeState.resolved => DisputeState.fixed,
    _ => state,
  };

  bool get isResolved =>
      canonicalState == DisputeState.fixed ||
      canonicalState == DisputeState.closed;

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
