import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/support_repository.dart';

enum SupportDetailPhase { initial, loading, loaded, sending, failed, conflict }

class SupportDetailState extends Equatable {
  const SupportDetailState({
    this.phase = SupportDetailPhase.initial,
    this.ticket,
    this.replyBody = '',
    this.attachmentPaths = const <String>[],
    this.attachmentBytes = const <String, Uint8List>{},
    this.uploads = const <String, CaseAttachmentProgress>{},
    this.failure,
    this.appFailure,
    this.refreshError,
    this.paginationAppFailure,
    this.operationId = '',
    this.nextCursor,
    this.loadingMore = false,
    this.paginationFailure,
  });

  final SupportDetailPhase phase;
  final SupportTicket? ticket;
  final String replyBody;
  final List<String> attachmentPaths;
  final Map<String, Uint8List> attachmentBytes;
  final Map<String, CaseAttachmentProgress> uploads;
  final SupportFailure? failure;

  /// The classified cold-read / send failure.
  final AppFailure? appFailure;

  /// A refresh that failed over a thread already on screen.
  final AppFailure? refreshError;

  /// The classified pagination failure.
  final AppFailure? paginationAppFailure;
  final String operationId;
  final String? nextCursor;
  final bool loadingMore;
  final SupportFailure? paginationFailure;

  bool get canReply =>
      ticket != null &&
      ticket!.canonicalStatus != SupportTicketStatus.closed &&
      replyBody.trim().isNotEmpty &&
      phase != SupportDetailPhase.sending;

  bool get canAttach =>
      attachmentPaths.length < 5 &&
      ticket?.canonicalStatus != SupportTicketStatus.closed;

  bool get canLoadMore =>
      nextCursor != null && nextCursor!.isNotEmpty && !loadingMore;

  SupportDetailState copyWith({
    SupportDetailPhase? phase,
    SupportTicket? ticket,
    String? replyBody,
    List<String>? attachmentPaths,
    Map<String, Uint8List>? attachmentBytes,
    Map<String, CaseAttachmentProgress>? uploads,
    SupportFailure? failure,
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    AppFailure? paginationAppFailure,
    bool clearFailure = false,
    String? operationId,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loadingMore,
    SupportFailure? paginationFailure,
    bool clearPaginationFailure = false,
  }) {
    return SupportDetailState(
      phase: phase ?? this.phase,
      ticket: ticket ?? this.ticket,
      replyBody: replyBody ?? this.replyBody,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      attachmentBytes: attachmentBytes ?? this.attachmentBytes,
      uploads: uploads ?? this.uploads,
      failure: clearFailure ? null : (failure ?? this.failure),
      appFailure: clearFailure ? null : (appFailure ?? this.appFailure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      paginationAppFailure: clearPaginationFailure
          ? null
          : (paginationAppFailure ?? this.paginationAppFailure),
      operationId: operationId ?? this.operationId,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      loadingMore: loadingMore ?? this.loadingMore,
      paginationFailure: clearPaginationFailure
          ? null
          : (paginationFailure ?? this.paginationFailure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    phase,
    ticket,
    replyBody,
    attachmentPaths,
    attachmentBytes.keys.toList(growable: false),
    uploads.entries
        .map(
          (entry) =>
              '${entry.key}:${entry.value.state.name}:'
              '${entry.value.sentBytes}:${entry.value.totalBytes}',
        )
        .toList(growable: false),
    failure,
    appFailure,
    refreshError,
    paginationAppFailure,
    operationId,
    nextCursor,
    loadingMore,
    paginationFailure,
  ];
}
