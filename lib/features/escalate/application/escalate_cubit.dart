import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/escalate_repository.dart';
import 'escalate_state.dart';

class EscalateCubit extends Cubit<EscalateState> {
  EscalateCubit({
    required EscalateRepository repository,
    required this.deliveryId,
    OperationIdFactory operationIdFactory = newOperationId,
  }) : _repository = repository,
       super(EscalateState(operationId: operationIdFactory()));

  final EscalateRepository _repository;
  final String deliveryId;
  bool _loadingEvidence = false;

  Future<void> loadEvidence() async {
    if (isClosed || state.evidenceLoaded || _loadingEvidence) return;
    _loadingEvidence = true;
    try {
      final evidence = await _repository.fetchEvidence(deliveryId: deliveryId);
      if (isClosed) return;
      emit(state.copyWith(evidence: evidence, evidenceLoaded: true));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(evidence: EscalateEvidence.empty, evidenceLoaded: true),
      );
    } finally {
      _loadingEvidence = false;
    }
  }

  void setReason(EscalateReason reason) {
    if (isClosed) return;
    emit(state.copyWith(reason: reason));
  }

  void setComment(String comment) {
    if (isClosed) return;
    emit(state.copyWith(comment: comment));
  }

  void addPhoto(String path, {List<int>? bytes}) {
    if (isClosed || state.photoPaths.length >= 5) return;
    final photoBytes = Map<String, dynamic>.from(state.photoBytes);
    if (bytes != null) {
      photoBytes[path] = Uint8List.fromList(bytes);
    }
    emit(
      state.copyWith(
        photoPaths: [...state.photoPaths, path],
        photoBytes: photoBytes.cast<String, Uint8List>(),
      ),
    );
  }

  void removePhoto(String path) {
    if (isClosed) return;
    final updated = List<String>.from(state.photoPaths)..remove(path);
    final bytes = Map<String, Uint8List>.from(state.photoBytes)..remove(path);
    final uploads = Map<String, CaseAttachmentProgress>.from(state.uploads)
      ..remove(path);
    emit(
      state.copyWith(photoPaths: updated, photoBytes: bytes, uploads: uploads),
    );
  }

  void setVoice(String path) {
    if (isClosed || path.isEmpty) return;
    emit(state.copyWith(voicePath: path));
  }

  void clearVoice() {
    if (isClosed) return;
    emit(state.copyWith(clearVoice: true));
  }

  Future<void> submit() async {
    if (isClosed ||
        !state.canSubmit ||
        state.phase == EscalatePhase.submitting) {
      return;
    }
    emit(state.copyWith(phase: EscalatePhase.submitting, clearError: true));
    try {
      final submission = EscalateSubmission(
        operationId: state.operationId,
        deliveryId: deliveryId,
        reason: state.reason!,
        comment: state.comment.isEmpty ? null : state.comment,
        attachments: _attachments(),
        evidence: state.evidence,
      );
      final repository = _repository;
      final result = repository is EscalateV2Repository
          ? await (repository as EscalateV2Repository).submitReport(
              submission,
              onProgress: _onUploadProgress,
            )
          : await repository.submitEscalation(
              deliveryId: deliveryId,
              reason: state.reason!,
              comment: state.comment.isEmpty ? null : state.comment,
              photoPaths: state.photoPaths,
              voicePath: state.voicePath,
              evidence: state.evidence,
            );
      if (isClosed) return;
      emit(state.copyWith(phase: EscalatePhase.success, caseId: result.caseId));
    } on EscalateException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(phase: EscalatePhase.error, errorKind: e.kind));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: EscalatePhase.error,
          errorKind: EscalateErrorKind.server,
        ),
      );
    }
  }

  void retryFromError() {
    if (isClosed) return;
    emit(state.copyWith(phase: EscalatePhase.inputting, clearError: true));
  }

  List<CaseAttachmentDraft> _attachments() {
    final attachments = <CaseAttachmentDraft>[
      for (final path in state.photoPaths)
        CaseAttachmentDraft(
          localId: path,
          fileName: path.split('/').last,
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
          bytes: state.photoBytes[path],
          path: state.photoBytes[path] == null ? path : null,
        ),
    ];
    final voicePath = state.voicePath;
    if (voicePath != null && voicePath.isNotEmpty) {
      attachments.add(
        CaseAttachmentDraft(
          localId: 'voice',
          fileName: voicePath.split('/').last,
          contentType: 'audio/mp4',
          kind: CaseAttachmentKind.voice,
          path: voicePath,
        ),
      );
    }
    return attachments;
  }

  void _onUploadProgress(CaseAttachmentProgress progress) {
    if (isClosed) return;
    final uploads = Map<String, CaseAttachmentProgress>.from(state.uploads)
      ..[progress.localId] = progress;
    emit(state.copyWith(uploads: uploads));
  }
}
