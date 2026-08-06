import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/support_repository.dart';
import 'support_state.dart';

class SupportCubit extends Cubit<SupportState> {
  SupportCubit(
    this._repository, {
    String? initialOrderRef,
    OperationIdFactory operationIdFactory = newOperationId,
  }) : super(
         SupportState(
           orderRef: initialOrderRef,
           operationId: operationIdFactory(),
         ),
       );

  final SupportRepository _repository;

  void setCategory(SupportCategory category) {
    if (isClosed) return;
    emit(state.copyWith(category: category, clearFailure: true));
  }

  void setBody(String body) {
    if (isClosed) return;
    emit(state.copyWith(body: body, clearFailure: true));
  }

  void setOrderRef(String? orderRef) {
    if (isClosed) return;
    final trimmed = orderRef?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      emit(state.copyWith(clearOrderRef: true));
    } else {
      emit(state.copyWith(orderRef: trimmed));
    }
  }

  void addAttachment(String path, {List<int>? bytes}) {
    if (isClosed || !state.canAttach) return;
    final attachmentBytes = Map<String, Uint8List>.from(state.attachmentBytes);
    if (bytes != null) attachmentBytes[path] = Uint8List.fromList(bytes);
    emit(
      state.copyWith(
        attachmentPaths: <String>[...state.attachmentPaths, path],
        attachmentBytes: attachmentBytes,
      ),
    );
  }

  void removeAttachment(String path) {
    if (isClosed) return;
    final updated = List<String>.from(state.attachmentPaths)..remove(path);
    final bytes = Map<String, Uint8List>.from(state.attachmentBytes)
      ..remove(path);
    final uploads = Map<String, CaseAttachmentProgress>.from(state.uploads)
      ..remove(path);
    emit(
      state.copyWith(
        attachmentPaths: updated,
        attachmentBytes: bytes,
        uploads: uploads,
      ),
    );
  }

  Future<void> submit() async {
    if (isClosed ||
        !state.canSubmit ||
        state.phase == SupportPhase.submitting) {
      return;
    }
    emit(state.copyWith(phase: SupportPhase.submitting, clearFailure: true));
    try {
      final draft = SupportTicketDraft(
        category: state.category!,
        body: state.body.trim(),
        orderRef: state.orderRef,
        attachmentPaths: state.attachmentPaths,
        attachments: _attachments(),
        operationId: state.operationId,
      );
      final repository = _repository;
      final ticket = repository is SupportTicketV2Repository
          ? await (repository as SupportTicketV2Repository).submitTicketV2(
              draft,
              onProgress: _onUploadProgress,
            )
          : await repository.submitTicket(draft);
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: SupportPhase.success,
          ticketId: ticket.id,
          ticket: ticket,
        ),
      );
    } on SupportRepositoryException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(phase: SupportPhase.error, failure: e.failure));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: SupportPhase.error,
          failure: SupportFailure.unknown,
        ),
      );
    }
  }

  void retryFromError() {
    if (isClosed) return;
    emit(state.copyWith(phase: SupportPhase.inputting, clearFailure: true));
  }

  List<CaseAttachmentDraft> _attachments() => state.attachmentPaths
      .map((path) {
        final bytes = state.attachmentBytes[path];
        return CaseAttachmentDraft(
          localId: path,
          fileName: path.split('/').last,
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
          bytes: bytes,
          path: bytes == null ? path : null,
        );
      })
      .toList(growable: false);

  void _onUploadProgress(CaseAttachmentProgress progress) {
    if (isClosed) return;
    final uploads = Map<String, CaseAttachmentProgress>.from(state.uploads)
      ..[progress.localId] = progress;
    emit(state.copyWith(uploads: uploads));
  }
}
