import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/escalate_repository.dart';
import 'escalate_state.dart';

/// Cubit driving the escalate/dispute flow (T-MOB-022).
///
/// Flow: inputting → submitting → success | error
class EscalateCubit extends Cubit<EscalateState> {
  EscalateCubit({
    required EscalateRepository repository,
    required this.deliveryId,
  })  : _repository = repository,
        super(const EscalateState());

  final EscalateRepository _repository;
  final String deliveryId;

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

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(phase: EscalatePhase.submitting));
    try {
      final result = await _repository.submitEscalation(
        deliveryId: deliveryId,
        reason: state.reason!,
        comment: state.comment.isEmpty ? null : state.comment,
        photoPaths: state.photoPaths,
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
