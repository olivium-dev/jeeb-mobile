/// Designed states for EscalateScreen (JM-060).
/// fetchEvidence and submitEscalation are scripted independently.

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
