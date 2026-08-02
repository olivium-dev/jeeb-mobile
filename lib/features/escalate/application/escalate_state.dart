import 'package:equatable/equatable.dart';

import '../domain/escalate_repository.dart';

enum EscalatePhase { inputting, submitting, success, error }

class EscalateState extends Equatable {
  const EscalateState({
    this.phase = EscalatePhase.inputting,
    this.reason,
    this.comment = '',
    this.photoPaths = const [],
    this.voicePath,
    this.evidence = EscalateEvidence.empty,
    this.evidenceLoaded = false,
    this.caseId,
    this.errorKind,
  });

  final EscalatePhase phase;
  final EscalateReason? reason;
  final String comment;
  final List<String> photoPaths;

  final String? voicePath;

  final EscalateEvidence evidence;

  final bool evidenceLoaded;

  final String? caseId;
  final EscalateErrorKind? errorKind;

  bool get canSubmit => reason != null;
  bool get hasVoice => (voicePath ?? '').isNotEmpty;
  bool get canAddPhoto => photoPaths.length < 5;
  int get photosRemaining => 5 - photoPaths.length;

  EscalateState copyWith({
    EscalatePhase? phase,
    EscalateReason? reason,
    String? comment,
    List<String>? photoPaths,
    String? voicePath,
    bool clearVoice = false,
    EscalateEvidence? evidence,
    bool? evidenceLoaded,
    String? caseId,
    EscalateErrorKind? errorKind,
  }) {
    return EscalateState(
      phase: phase ?? this.phase,
      reason: reason ?? this.reason,
      comment: comment ?? this.comment,
      photoPaths: photoPaths ?? this.photoPaths,
      voicePath: clearVoice ? null : (voicePath ?? this.voicePath),
      evidence: evidence ?? this.evidence,
      evidenceLoaded: evidenceLoaded ?? this.evidenceLoaded,
      caseId: caseId ?? this.caseId,
      errorKind: errorKind ?? this.errorKind,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        reason,
        comment,
        photoPaths,
        voicePath,
        evidence.chatSnapshotUrl,
        evidence.chatMessageCount,
        evidence.timeline.length,
        evidenceLoaded,
        caseId,
        errorKind,
      ];
}
