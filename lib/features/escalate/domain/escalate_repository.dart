import '../../../core/network/app_failure.dart';
import '../../case_evidence/domain/case_evidence.dart';

class EscalateEvidence {
  const EscalateEvidence({
    this.chatSnapshotUrl,
    this.chatMessageCount,
    this.timeline = const <EscalateTimelineEntry>[],
    this.missingSources = const <String>[],
  });

  /// CDN URL of the immutable conversation snapshot (D53). Null when the originating order has no conversation (or the fetch degraded gracefully).
  final String? chatSnapshotUrl;

  final int? chatMessageCount;

  final List<EscalateTimelineEntry> timeline;

  /// Gateway evidence sources that could not be read at draft time.
  final List<String> missingSources;

  bool get hasChatSnapshot => (chatSnapshotUrl ?? '').isNotEmpty;
  bool get hasTimeline => timeline.isNotEmpty;
  bool get isEmpty => !hasChatSnapshot && !hasTimeline;
  bool get isPartial => missingSources.isNotEmpty;

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

/// The evidence-preview lane. A repository implements this ONLY when a real
/// preview endpoint stands behind it, so an "empty evidence" rung never lies.
abstract class EscalateEvidencePreviewRepository {
  Future<EscalateEvidence> previewEvidence({required String deliveryId});
}

abstract class EscalateV2Repository {
  Future<EscalateResult> submitReport(
    EscalateSubmission submission, {
    CaseAttachmentProgressCallback? onProgress,
  });
}

class EscalateSubmission {
  const EscalateSubmission({
    required this.operationId,
    required this.deliveryId,
    required this.reason,
    required this.evidence,
    this.comment,
    this.attachments = const <CaseAttachmentDraft>[],
  });

  final String operationId;
  final String deliveryId;
  final EscalateReason reason;
  final String? comment;
  final List<CaseAttachmentDraft> attachments;
  final EscalateEvidence evidence;
}

enum EscalateReason { damaged, wrongItem, noShow, fraud, abuse, other }

class EscalateResult {
  const EscalateResult({
    required this.caseId,
    required this.status,
    this.version,
  });

  factory EscalateResult.fromJson(Map<String, dynamic> json) {
    return EscalateResult(
      caseId:
          json['id'] as String? ??
          json['disputeId'] as String? ??
          json['caseId'] as String? ??
          json['case_id'] as String? ??
          '',
      status:
          json['status'] as String? ?? json['state'] as String? ?? 'pending',
      version: json['version'] is num ? (json['version'] as num).toInt() : null,
    );
  }

  final String caseId;
  final String status;
  final int? version;
}

class EscalateException implements Exception {
  const EscalateException(this.kind, [this.cause]) : failure = null;

  const EscalateException.classified(
    this.kind, {
    this.cause,
    required this.failure,
  });

  final EscalateErrorKind kind;
  final Object? cause;

  /// The classified transport failure, when the thrower could produce one.
  final AppFailure? failure;

  @override
  String toString() =>
      'EscalateException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum EscalateErrorKind {
  network,
  server,
  evidenceUpload,
  alreadyOpen,
  notFound,
}
