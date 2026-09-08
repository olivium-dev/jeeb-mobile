// Shared dev-only upload-progress scripts for the escalate and support upload
// rows, so both surfaces preview the SAME three progress shapes.

import '../../../features/case_evidence/domain/case_evidence.dart';

/// The scripted progress sequences every upload preview replays.
abstract final class CaseEvidenceFixtures {
  /// The local id the escalate and support previews both attach.
  static const String localId = 'case_evidence_preview_1.jpg';

  /// Mid-flight: the bar is moving.
  static const CaseAttachmentProgress uploading = CaseAttachmentProgress(
    localId: localId,
    state: CaseAttachmentUploadState.uploading,
    sentBytes: 512 * 1024,
    totalBytes: 2 * 1024 * 1024,
  );

  /// Settled: the row shows the uploaded mark, no bar.
  static const CaseAttachmentProgress uploaded = CaseAttachmentProgress(
    localId: localId,
    state: CaseAttachmentUploadState.uploaded,
    sentBytes: 2 * 1024 * 1024,
    totalBytes: 2 * 1024 * 1024,
    objectRef: 'cdn://case-evidence/preview-1',
  );

  /// Failed. Note the ABSENT message: the row renders the failure kind from
  /// the classified `AppFailure`, never repository prose (R6).
  static const CaseAttachmentProgress failed = CaseAttachmentProgress(
    localId: localId,
    state: CaseAttachmentUploadState.failed,
    sentBytes: 512 * 1024,
    totalBytes: 2 * 1024 * 1024,
  );

  /// The whole arc, in order — for a preview that steps through it.
  static const List<CaseAttachmentProgress> arc = <CaseAttachmentProgress>[
    uploading,
    uploaded,
  ];

  /// The failing arc.
  static const List<CaseAttachmentProgress> failingArc =
      <CaseAttachmentProgress>[uploading, failed];
}
