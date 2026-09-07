import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/escalate_repository.dart';

enum EscalatePhase { inputting, submitting, success, error }

class EscalateState extends Equatable {
  const EscalateState({
    this.phase = EscalatePhase.inputting,
    this.reason,
    this.comment = '',
    this.photoPaths = const [],
    this.photoBytes = const <String, Uint8List>{},
    this.voicePath,
    this.evidence = EscalateEvidence.empty,
    this.evidenceLoaded = false,
    this.evidenceLoading = false,
    this.evidenceLoadFailed = false,
    this.caseId,
    this.errorKind,
    this.failure,
    this.uploads = const <String, CaseAttachmentProgress>{},
    this.operationId = '',
  });

  final EscalatePhase phase;
  final EscalateReason? reason;
  final String comment;
  final List<String> photoPaths;
  final Map<String, Uint8List> photoBytes;

  final String? voicePath;

  final EscalateEvidence evidence;

  final bool evidenceLoaded;

  /// The preview read is in flight.
  final bool evidenceLoading;

  /// The preview read failed — distinct from "there is no evidence".
  final bool evidenceLoadFailed;

  final String? caseId;
  final EscalateErrorKind? errorKind;

  /// The classified failure behind [errorKind] / [evidenceLoadFailed].
  final AppFailure? failure;
  final Map<String, CaseAttachmentProgress> uploads;
  final String operationId;

  bool get canSubmit => reason != null;
  bool get hasVoice => (voicePath ?? '').isNotEmpty;
  bool get canAddPhoto => photoPaths.length < 5;
  int get photosRemaining => 5 - photoPaths.length;
  bool get hasUploadFailures => uploads.values.any(
    (item) => item.state == CaseAttachmentUploadState.failed,
  );

  EscalateState copyWith({
    EscalatePhase? phase,
    EscalateReason? reason,
    String? comment,
    List<String>? photoPaths,
    Map<String, Uint8List>? photoBytes,
    String? voicePath,
    bool clearVoice = false,
    EscalateEvidence? evidence,
    bool? evidenceLoaded,
    bool? evidenceLoading,
    bool? evidenceLoadFailed,
    String? caseId,
    EscalateErrorKind? errorKind,
    AppFailure? failure,
    bool clearFailure = false,
    bool clearError = false,
    Map<String, CaseAttachmentProgress>? uploads,
    String? operationId,
  }) {
    return EscalateState(
      phase: phase ?? this.phase,
      reason: reason ?? this.reason,
      comment: comment ?? this.comment,
      photoPaths: photoPaths ?? this.photoPaths,
      photoBytes: photoBytes ?? this.photoBytes,
      voicePath: clearVoice ? null : (voicePath ?? this.voicePath),
      evidence: evidence ?? this.evidence,
      evidenceLoaded: evidenceLoaded ?? this.evidenceLoaded,
      evidenceLoading: evidenceLoading ?? this.evidenceLoading,
      evidenceLoadFailed: evidenceLoadFailed ?? this.evidenceLoadFailed,
      caseId: caseId ?? this.caseId,
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
      failure: (clearError || clearFailure) ? null : (failure ?? this.failure),
      uploads: uploads ?? this.uploads,
      operationId: operationId ?? this.operationId,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    reason,
    comment,
    photoPaths,
    photoBytes.keys.toList(growable: false),
    voicePath,
    evidence.chatSnapshotUrl,
    evidence.chatMessageCount,
    evidence.timeline.length,
    evidenceLoaded,
    evidenceLoading,
    evidenceLoadFailed,
    caseId,
    errorKind,
    failure,
    uploads.entries
        .map(
          (entry) =>
              '${entry.key}:${entry.value.state.name}:'
              '${entry.value.sentBytes}:${entry.value.totalBytes}',
        )
        .toList(growable: false),
    operationId,
  ];
}
