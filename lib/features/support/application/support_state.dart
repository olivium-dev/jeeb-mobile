import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../case_evidence/domain/case_evidence.dart';
import '../domain/support_repository.dart';

enum SupportPhase { inputting, submitting, success, error }

class SupportState extends Equatable {
  const SupportState({
    this.phase = SupportPhase.inputting,
    this.category,
    this.body = '',
    this.orderRef,
    this.attachmentPaths = const <String>[],
    this.attachmentBytes = const <String, Uint8List>{},
    this.ticketId,
    this.ticket,
    this.failure,
    this.uploads = const <String, CaseAttachmentProgress>{},
    this.operationId = '',
  });

  final SupportPhase phase;

  final SupportCategory? category;

  final String body;

  final String? orderRef;

  final List<String> attachmentPaths;
  final Map<String, Uint8List> attachmentBytes;

  final String? ticketId;
  final SupportTicket? ticket;

  final SupportFailure? failure;
  final Map<String, CaseAttachmentProgress> uploads;
  final String operationId;

  bool get canSubmit => category != null && body.trim().isNotEmpty;

  bool get canAttach => attachmentPaths.length < 5;
  bool get hasUploadFailures => uploads.values.any(
    (item) => item.state == CaseAttachmentUploadState.failed,
  );

  SupportState copyWith({
    SupportPhase? phase,
    SupportCategory? category,
    String? body,
    String? orderRef,
    bool clearOrderRef = false,
    List<String>? attachmentPaths,
    Map<String, Uint8List>? attachmentBytes,
    String? ticketId,
    SupportTicket? ticket,
    SupportFailure? failure,
    bool clearFailure = false,
    Map<String, CaseAttachmentProgress>? uploads,
    String? operationId,
  }) {
    return SupportState(
      phase: phase ?? this.phase,
      category: category ?? this.category,
      body: body ?? this.body,
      orderRef: clearOrderRef ? null : (orderRef ?? this.orderRef),
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      attachmentBytes: attachmentBytes ?? this.attachmentBytes,
      ticketId: ticketId ?? this.ticketId,
      ticket: ticket ?? this.ticket,
      failure: clearFailure ? null : (failure ?? this.failure),
      uploads: uploads ?? this.uploads,
      operationId: operationId ?? this.operationId,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    phase,
    category,
    body,
    orderRef,
    attachmentPaths,
    attachmentBytes.keys.toList(growable: false),
    ticketId,
    ticket,
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
