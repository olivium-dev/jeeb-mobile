import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/support_repository.dart';
import 'support_detail_state.dart';

class SupportDetailCubit extends Cubit<SupportDetailState> {
  SupportDetailCubit({
    required SupportThreadRepository repository,
    required this.ticketId,
    OperationIdFactory operationIdFactory = newOperationId,
  }) : _repository = repository,
       _operationIdFactory = operationIdFactory,
       super(SupportDetailState(operationId: operationIdFactory()));

  final SupportThreadRepository _repository;
  final OperationIdFactory _operationIdFactory;
  final String ticketId;
  int _loadGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;
    if (ticketId.trim().isEmpty) {
      emit(
        state.copyWith(
          phase: SupportDetailPhase.failed,
          failure: SupportFailure.notFound,
        ),
      );
      return;
    }
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        phase: SupportDetailPhase.loading,
        loadingMore: false,
        clearFailure: true,
        clearPaginationFailure: true,
      ),
    );
    try {
      final repository = _repository;
      final SupportTicket ticket;
      final String? nextCursor;
      if (repository is PaginatedSupportThreadRepository) {
        final page = await (repository as PaginatedSupportThreadRepository)
            .fetchInitialThread(ticketId);
        ticket = page.ticket;
        nextCursor = page.nextCursor;
      } else {
        ticket = await repository.fetchTicket(ticketId);
        nextCursor = null;
      }
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          phase: SupportDetailPhase.loaded,
          ticket: ticket,
          nextCursor: nextCursor,
          clearNextCursor: nextCursor == null,
          clearFailure: true,
          clearPaginationFailure: true,
        ),
      );
    } on SupportRepositoryException catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          phase: SupportDetailPhase.failed,
          failure: error.failure,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          phase: SupportDetailPhase.failed,
          failure: SupportFailure.unknown,
        ),
      );
    }
  }

  Future<void> refresh() => load();

  void setReplyBody(String value) {
    if (isClosed) return;
    emit(state.copyWith(replyBody: value, clearFailure: true));
  }

  void addAttachment(String path, {List<int>? bytes}) {
    if (isClosed || !state.canAttach) return;
    final values = Map<String, Uint8List>.from(state.attachmentBytes);
    if (bytes != null) values[path] = Uint8List.fromList(bytes);
    emit(
      state.copyWith(
        attachmentPaths: <String>[...state.attachmentPaths, path],
        attachmentBytes: values,
      ),
    );
  }

  void removeAttachment(String path) {
    if (isClosed) return;
    final paths = List<String>.from(state.attachmentPaths)..remove(path);
    final bytes = Map<String, Uint8List>.from(state.attachmentBytes)
      ..remove(path);
    final uploads = Map<String, CaseAttachmentProgress>.from(state.uploads)
      ..remove(path);
    emit(
      state.copyWith(
        attachmentPaths: paths,
        attachmentBytes: bytes,
        uploads: uploads,
      ),
    );
  }

  Future<void> sendReply() async {
    if (isClosed || !state.canReply) return;
    final generation = ++_loadGeneration;
    final ticket = state.ticket!;
    emit(state.copyWith(phase: SupportDetailPhase.sending, clearFailure: true));
    try {
      final updated = await _repository.replyToTicket(
        ticket.id,
        SupportReplyDraft(
          operationId: state.operationId,
          body: state.replyBody.trim(),
          version: ticket.version,
          attachments: _attachments(),
        ),
        onProgress: _onProgress,
      );
      if (isClosed || generation != _loadGeneration) return;
      emit(
        SupportDetailState(
          phase: SupportDetailPhase.loaded,
          ticket: updated,
          operationId: _operationIdFactory(),
        ),
      );
    } on SupportRepositoryException catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          phase: error.failure == SupportFailure.conflict
              ? SupportDetailPhase.conflict
              : SupportDetailPhase.loaded,
          ticket: error.latestTicket,
          failure: error.failure,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          phase: SupportDetailPhase.loaded,
          failure: SupportFailure.unknown,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final repository = _repository;
    final cursor = state.nextCursor;
    if (isClosed ||
        repository is! PaginatedSupportThreadRepository ||
        cursor == null ||
        cursor.isEmpty ||
        state.loadingMore ||
        state.ticket == null) {
      return;
    }
    final generation = _loadGeneration;
    emit(state.copyWith(loadingMore: true, clearPaginationFailure: true));
    try {
      final page = await (repository as PaginatedSupportThreadRepository)
          .fetchMessages(
            ticketId,
            cursor: cursor,
            initialRequestBody: state.ticket!.body,
          );
      if (isClosed || generation != _loadGeneration) return;
      final replies = <SupportReply>[];
      final ids = <String>{};
      for (final reply in <SupportReply>[
        ...state.ticket!.replies,
        ...page.ticket.replies,
      ]) {
        if (ids.add(reply.id)) replies.add(reply);
      }
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final nextCursor = page.nextCursor == cursor ? null : page.nextCursor;
      emit(
        state.copyWith(
          ticket: state.ticket!.copyWith(replies: replies),
          nextCursor: nextCursor,
          clearNextCursor: nextCursor == null,
          loadingMore: false,
          clearPaginationFailure: true,
        ),
      );
    } on SupportRepositoryException catch (error) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(loadingMore: false, paginationFailure: error.failure),
      );
    } catch (_) {
      if (isClosed || generation != _loadGeneration) return;
      emit(
        state.copyWith(
          loadingMore: false,
          paginationFailure: SupportFailure.unknown,
        ),
      );
    }
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

  void _onProgress(CaseAttachmentProgress progress) {
    if (isClosed) return;
    final uploads = Map<String, CaseAttachmentProgress>.from(state.uploads)
      ..[progress.localId] = progress;
    emit(state.copyWith(uploads: uploads));
  }
}
