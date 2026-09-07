/// Designed states for EscalateScreen (JM-060).
/// fetchEvidence and submitEscalation are scripted independently.
library;

import 'dart:async';

import '../../../features/escalate/application/escalate_cubit.dart';
import '../../../features/escalate/domain/escalate_repository.dart';

/// Fake repository with independent script axes.
class ScriptedEscalateRepository implements EscalateRepository {
  const ScriptedEscalateRepository({
    this.evidence = EscalateScreenPreviewFixtures.fullEvidence,
    this.evidenceFailure,
    this.evidenceStalls = false,
    this.submitFailure,
    this.submitStalls = false,
    this.caseId = EscalateScreenPreviewFixtures.caseId,
  });

  /// Successful fetchEvidence result.
  final EscalateEvidence evidence;

  /// fetchEvidence error; causes loadEvidence to degrade.
  final EscalateErrorKind? evidenceFailure;

  /// fetchEvidence stalls (never resolves).
  final bool evidenceStalls;

  /// submitEscalation error.
  final EscalateErrorKind? submitFailure;

  /// submitEscalation stalls.
  final bool submitStalls;

  /// Dispute id on successful submit.
  final String caseId;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) {
    if (evidenceStalls) return Completer<EscalateEvidence>().future;
    final EscalateErrorKind? failure = evidenceFailure;
    if (failure != null) {
      return Future<EscalateEvidence>.error(EscalateException(failure));
    }
    return Future<EscalateEvidence>.value(evidence);
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    if (submitStalls) return Completer<EscalateResult>().future;
    final EscalateErrorKind? failure = submitFailure;
    if (failure != null) {
      return Future<EscalateResult>.error(EscalateException(failure));
    }
    return Future<EscalateResult>.value(
      EscalateResult(caseId: caseId, status: 'open'),
    );
  }
}

/// A repository that DOES serve an evidence preview (ES-15). Production's
/// `DioEscalateRepository` deliberately does not, so the rung never lies.
class ScriptedEscalatePreviewRepository extends ScriptedEscalateRepository
    implements EscalateEvidencePreviewRepository {
  const ScriptedEscalatePreviewRepository({
    super.evidence,
    this.previewStalls = false,
    this.previewFails = false,
    super.submitFailure,
  });

  final bool previewStalls;
  final bool previewFails;

  @override
  Future<EscalateEvidence> previewEvidence({required String deliveryId}) {
    if (previewStalls) return Completer<EscalateEvidence>().future;
    if (previewFails) {
      return Future<EscalateEvidence>.error(
        const EscalateException(EscalateErrorKind.server),
      );
    }
    return Future<EscalateEvidence>.value(evidence);
  }
}

/// EscalateScreen designed states.
class EscalateScreenPreviewFixtures {
  const EscalateScreenPreviewFixtures._();

  /// Delivery id for all states.
  static const String deliveryId = 'DEL-1001';

  /// Dispute id on successful submit.
  static const String caseId = 'DSP-1001';

  /// In-flight delivery auto-attach (3 timeline states).
  static const EscalateEvidence fullEvidence = EscalateEvidence(
    chatSnapshotUrl: 'https://cdn.example.com/dispute/snapshot.png',
    chatMessageCount: 12,
    timeline: <EscalateTimelineEntry>[
      EscalateTimelineEntry(status: 'Ordered'),
      EscalateTimelineEntry(status: 'Picked'),
      EscalateTimelineEntry(status: 'InTransit'),
    ],
  );

  /// Completed delivery auto-attach.
  static const EscalateEvidence completedEvidence = EscalateEvidence(
    chatSnapshotUrl: 'https://cdn.example.com/dispute/snapshot-248.png',
    chatMessageCount: 248,
    timeline: <EscalateTimelineEntry>[
      EscalateTimelineEntry(status: 'Ordered'),
      EscalateTimelineEntry(status: 'Picked'),
      EscalateTimelineEntry(status: 'InTransit'),
      EscalateTimelineEntry(status: 'Done'),
    ],
  );

  /// Max 5 photo paths.
  static const List<String> cappedPhotos = <String>[
    'dispute_photo_1.jpg',
    'dispute_photo_2.jpg',
    'dispute_photo_3.jpg',
    'dispute_photo_4.jpg',
    'dispute_photo_5.jpg',
  ];

  /// Voice evidence clip.
  static const String voicePath = 'dispute_voice.m4a';

  /// Evidence loaded state.
  static EscalateRepository evidenceLoaded() =>
      const ScriptedEscalateRepository();

  /// Evidence fetch failed; degrades to empty.
  static EscalateRepository evidenceDegraded() =>
      const ScriptedEscalateRepository(
        evidenceFailure: EscalateErrorKind.network,
      );

  /// Evidence still in flight.
  static EscalateRepository evidenceStalled() =>
      const ScriptedEscalateRepository(evidenceStalls: true);

  /// Submit stalled; phase stays submitting.
  static EscalateRepository stalledSubmit() =>
      const ScriptedEscalateRepository(submitStalls: true);

  /// Submit fails with error.
  static EscalateRepository failingSubmit([
    EscalateErrorKind kind = EscalateErrorKind.network,
  ]) => ScriptedEscalateRepository(submitFailure: kind);

  /// Completed delivery's evidence.
  static EscalateRepository completedEvidenceLoaded() =>
      const ScriptedEscalateRepository(evidence: completedEvidence);

  /// ES-15: an empty preview, behind a repository that actually has one.
  static EscalateRepository emptyPreview() =>
      const ScriptedEscalatePreviewRepository(evidence: EscalateEvidence.empty);

  /// ES-15: the preview read failed — NOT the same as "no evidence".
  static EscalateRepository failingPreview() =>
      const ScriptedEscalatePreviewRepository(previewFails: true);

  /// ES-15: the preview is still in flight.
  static EscalateRepository stalledPreview() =>
      const ScriptedEscalatePreviewRepository(previewStalls: true);

  /// ES-15: a rich preview, behind a real preview endpoint.
  static EscalateRepository richPreview() =>
      const ScriptedEscalatePreviewRepository(evidence: fullEvidence);

  /// ESC-06: a dispute that no longer exists — exit CTA, never Retry.
  static EscalateRepository notFoundSubmit() =>
      const ScriptedEscalateRepository(
        submitFailure: EscalateErrorKind.notFound,
      );

  /// ESC-07: the v1 path, which now uploads before it POSTs.
  static EscalateRepository v1UploadFirst() =>
      const ScriptedEscalateRepository();

  /// Pre-configured cubit (no loadEvidence on purpose).
  static EscalateCubit cubit(
    EscalateRepository repository, {
    EscalateReason? reason,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    bool submit = false,
  }) {
    final EscalateCubit cubit = EscalateCubit(
      repository: repository,
      deliveryId: deliveryId,
    );
    if (reason != null) cubit.setReason(reason);
    for (final String path in photoPaths) {
      cubit.addPhoto(path);
    }
    if (voicePath != null) cubit.setVoice(voicePath);
    if (submit) unawaited(cubit.submit());
    return cubit;
  }
}
