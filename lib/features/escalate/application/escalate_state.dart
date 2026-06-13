import 'package:equatable/equatable.dart';

import '../domain/escalate_repository.dart';

enum EscalatePhase { inputting, submitting, success, error }

class EscalateState extends Equatable {
  const EscalateState({
    this.phase = EscalatePhase.inputting,
    this.reason,
    this.comment = '',
    this.photoPaths = const [],
    this.caseId,
    this.errorKind,
  });

  final EscalatePhase phase;
  final EscalateReason? reason;
  final String comment;
  final List<String> photoPaths;
  final String? caseId;
  final EscalateErrorKind? errorKind;

  bool get canSubmit => reason != null;

  EscalateState copyWith({
    EscalatePhase? phase,
    EscalateReason? reason,
    String? comment,
    List<String>? photoPaths,
    String? caseId,
    EscalateErrorKind? errorKind,
  }) {
    return EscalateState(
      phase: phase ?? this.phase,
      reason: reason ?? this.reason,
      comment: comment ?? this.comment,
      photoPaths: photoPaths ?? this.photoPaths,
      caseId: caseId ?? this.caseId,
      errorKind: errorKind ?? this.errorKind,
    );
  }

  @override
  List<Object?> get props =>
      [phase, reason, comment, photoPaths, caseId, errorKind];
}
