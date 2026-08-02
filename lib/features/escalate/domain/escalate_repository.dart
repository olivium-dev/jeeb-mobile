class EscalateEvidence {
  const EscalateEvidence({
    this.chatSnapshotUrl,
    this.chatMessageCount,
    this.timeline = const <EscalateTimelineEntry>[],
  });

/// CDN URL of the immutable conversation snapshot (D53). Null when the originating order has no conversation (or the fetch degraded gracefully).
  final String? chatSnapshotUrl;

  final int? chatMessageCount;

  final List<EscalateTimelineEntry> timeline;

  bool get hasChatSnapshot => (chatSnapshotUrl ?? '').isNotEmpty;
  bool get hasTimeline => timeline.isNotEmpty;
  bool get isEmpty => !hasChatSnapshot && !hasTimeline;

  static const EscalateEvidence empty = EscalateEvidence();
}

class EscalateTimelineEntry {
  const EscalateTimelineEntry({required this.status, this.at});

  final String status;

  final String? at;
}

abstract class EscalateRepository {
  Future<EscalateEvidence> fetchEvidence({required String deliveryId});

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
