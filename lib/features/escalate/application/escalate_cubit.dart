import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/escalate_repository.dart';
import 'escalate_state.dart';

/// Cubit driving dispute-open-evidence (JM-060, blueprint `dispute-open-evidence`).
///
/// Flow: inputting → submitting → success | error.
/// On cold entry it fetches the auto-attached evidence (D53 chat snapshot +
/// GPS/status timeline) in the background; that fetch never fails the screen
/// (degrades to empty). Photos cap at 5; voice is optional (D53).
class EscalateCubit extends Cubit<EscalateState> {
  EscalateCubit({
    required EscalateRepository repository,
    required this.deliveryId,
  })  : _repository = repository,
        super(const EscalateState());

  final EscalateRepository _repository;
  final String deliveryId;

  /// Resolve the auto-attached evidence (D53). Idempotent — safe to call once
  /// on first build. Never throws: a degraded fetch lands as empty evidence.
  Future<void> loadEvidence() async {
    if (state.evidenceLoaded) return;
    try {
      final evidence =
          await _repository.fetchEvidence(deliveryId: deliveryId);
      emit(state.copyWith(evidence: evidence, evidenceLoaded: true));
    } catch (_) {
      emit(state.copyWith(
        evidence: EscalateEvidence.empty,
        evidenceLoaded: true,
      ));
    }
  }

  void setReason(EscalateReason reason) {
    emit(state.copyWith(reason: reason));
  }

  void setComment(String comment) {
    emit(state.copyWith(comment: comment));
  }

  void addPhoto(String path) {
    if (state.photoPaths.length >= 5) return;
    emit(state.copyWith(photoPaths: [...state.photoPaths, path]));
  }

  void removePhoto(String path) {
    final updated = List<String>.from(state.photoPaths)..remove(path);
    emit(state.copyWith(photoPaths: updated));
  }

  /// Attach a captured voice clip (D53). [path] is the on-device file path.
  void setVoice(String path) {
    if (path.isEmpty) return;
    emit(state.copyWith(voicePath: path));
  }

  void clearVoice() {
    emit(state.copyWith(clearVoice: true));
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(phase: EscalatePhase.submitting));
    try {
      final result = await _repository.submitEscalation(
        deliveryId: deliveryId,
        reason: state.reason!,
        comment: state.comment.isEmpty ? null : state.comment,
        photoPaths: state.photoPaths,
        voicePath: state.voicePath,
        evidence: state.evidence,
      );
      emit(state.copyWith(phase: EscalatePhase.success, caseId: result.caseId));
    } on EscalateException catch (e) {
      emit(state.copyWith(phase: EscalatePhase.error, errorKind: e.kind));
    } catch (_) {
      emit(state.copyWith(
        phase: EscalatePhase.error,
        errorKind: EscalateErrorKind.server,
      ));
    }
  }

  void retryFromError() {
    emit(state.copyWith(phase: EscalatePhase.inputting));
  }
}
