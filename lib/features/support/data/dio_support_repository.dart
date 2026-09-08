import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../../case_evidence/data/dio_case_evidence_uploader.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/support_repository.dart';

class DioSupportRepository
    implements
        SupportRepository,
        SupportTicketV2Repository,
        SupportThreadRepository,
        PaginatedSupportThreadRepository {
  DioSupportRepository(this._dio, {CaseEvidenceUploader? evidenceUploader})
    : _evidenceUploader =
          evidenceUploader ??
          DioCaseEvidenceUploader(
            _dio,
            slot: CaseEvidenceSlot.supportAttachment,
          );

  final Dio _dio;
  final CaseEvidenceUploader _evidenceUploader;
  final Map<String, UploadedCaseAttachment> _uploaded =
      <String, UploadedCaseAttachment>{};
  final Map<String, Future<UploadedCaseAttachment>> _uploadsInFlight =
      <String, Future<UploadedCaseAttachment>>{};

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) {
    final operationId = isOperationId(draft.operationId)
        ? draft.operationId
        : newOperationId();
    return _createTicket(
      draft,
      operationId: operationId,
      uploaded: <UploadedCaseAttachment>[
        for (final path in draft.attachmentPaths)
          UploadedCaseAttachment(
            localId: path,
            objectRef: path,
            fileName: path.split('/').last,
            contentType: 'image/jpeg',
            kind: CaseAttachmentKind.photo,
          ),
      ],
    );
  }

  @override
  Future<SupportTicket> submitTicketV2(
    SupportTicketDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    final uploaded = await _uploadAll(
      draft.attachments,
      operationId: draft.operationId,
      onProgress: onProgress,
    );
    return _createTicket(
      draft,
      operationId: draft.operationId,
      uploaded: uploaded,
    );
  }

  Future<SupportTicket> _createTicket(
    SupportTicketDraft draft, {
    required String operationId,
    required List<UploadedCaseAttachment> uploaded,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/support/tickets',
        data: <String, Object?>{
          'operationId': operationId,
          'category': draft.category.name,
          'body': draft.body,
          if (draft.orderRef != null) 'orderRef': draft.orderRef,
          if (uploaded.isNotEmpty)
            'attachments': uploaded
                .map((item) => item.objectRef)
                .toList(growable: false),
        },
        options: Options(
          headers: <String, Object?>{'Idempotency-Key': operationId},
        ),
      );
      return _ticket(_body(res.data), fallbackId: '');
    } on DioException catch (error) {
      final existing = _ticketFromConflict(error.response?.data);
      if (error.response?.statusCode == 409) {
        if (existing != null) return existing;
        final existingId = _existingCaseId(error.response?.data);
        if (existingId != null) {
          // Never fabricate a ticket: when the follow-up read fails the
          // conflict travels typed and the screen offers the existing one.
          final recovered = await _fetchAfterConflict(existingId);
          if (recovered != null) return recovered;
          throw SupportRepositoryException.classified(
            SupportFailure.conflict,
            message: 'Existing ticket $existingId could not be read.',
            appFailure: AppFailure.of(error),
          );
        }
      }
      throw SupportRepositoryException.classified(
        _map(error),
        message: error.message,
        appFailure: AppFailure.of(error),
      );
    }
  }

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/support/tickets/$ticketId',
      );
      return _ticket(
        _body(response.data),
        fallbackId: ticketId,
        includeMessages: false,
      );
    } on DioException catch (error) {
      throw SupportRepositoryException.classified(
        _map(error),
        message: error.message,
        appFailure: AppFailure.of(error),
      );
    }
  }

  @override
  Future<SupportThreadPage> fetchInitialThread(
    String ticketId, {
    int limit = 20,
  }) async {
    final ticket = await fetchTicket(ticketId);
    final page = await _fetchMessages(
      ticketId,
      limit: limit,
      initialBody: ticket.body,
    );
    return SupportThreadPage(
      ticket: ticket.copyWith(replies: page.ticket.replies),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<SupportThreadPage> fetchMessages(
    String ticketId, {
    String? cursor,
    int limit = 20,
    String? initialRequestBody,
  }) {
    return _fetchMessages(
      ticketId,
      cursor: cursor,
      limit: limit,
      initialBody: initialRequestBody,
    );
  }

  Future<SupportThreadPage> _fetchMessages(
    String ticketId, {
    String? cursor,
    required int limit,
    String? initialBody,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/support/tickets/$ticketId/messages',
        queryParameters: <String, Object?>{
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
      );
      final raw = response.data ?? const <String, dynamic>{};
      final messages = raw['items'] ?? raw['messages'];
      final nextCursor = _str(raw['nextCursor'] ?? raw['cursor']);
      return SupportThreadPage(
        ticket: SupportTicket(
          id: ticketId,
          status: 'pending',
          replies: _replies(
            messages,
            // The gateway starts with the newest bounded window and walks
            // earlier. The original request is only present on the terminal
            // oldest page, where nextCursor is null.
            excludeInitialRequest: nextCursor == null && initialBody != null,
            initialBody: initialBody,
          ),
        ),
        nextCursor: nextCursor,
      );
    } on DioException catch (error) {
      throw SupportRepositoryException.classified(
        _map(error),
        message: error.message,
        appFailure: AppFailure.of(error),
      );
    }
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    final uploaded = await _uploadAll(
      draft.attachments,
      operationId: draft.operationId,
      onProgress: onProgress,
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/support/tickets/$ticketId/reply',
        data: <String, Object?>{
          'operationId': draft.operationId,
          'body': draft.body,
          'expectedVersion': draft.version,
          if (uploaded.isNotEmpty)
            'attachments': uploaded
                .map((item) => item.objectRef)
                .toList(growable: false),
        },
        options: Options(
          headers: <String, Object?>{
            'Idempotency-Key': draft.operationId,
            'If-Match': '${draft.version}',
          },
        ),
      );
      return _ticket(_body(response.data), fallbackId: ticketId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 409 ||
          error.response?.statusCode == 412) {
        SupportTicket? latest = _ticketFromConflict(error.response?.data);
        final existingId = _existingCaseId(error.response?.data);
        latest ??= await _fetchAfterConflict(existingId ?? ticketId);
        throw SupportRepositoryException.classified(
          SupportFailure.conflict,
          message: 'Ticket changed while this reply was being sent.',
          latestTicket: latest,
          appFailure: AppFailure.of(error),
        );
      }
      throw SupportRepositoryException.classified(
        _map(error),
        message: error.message,
        appFailure: AppFailure.of(error),
      );
    }
  }

  Future<List<UploadedCaseAttachment>> _uploadAll(
    List<CaseAttachmentDraft> attachments, {
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    final result = <UploadedCaseAttachment>[];
    for (final attachment in attachments) {
      final cacheKey = '$operationId:${attachment.localId}';
      final cached = _uploaded[cacheKey];
      if (cached != null) {
        result.add(cached);
        onProgress?.call(
          CaseAttachmentProgress(
            localId: attachment.localId,
            state: CaseAttachmentUploadState.uploaded,
            objectRef: cached.objectRef,
          ),
        );
        continue;
      }
      try {
        final inFlight = _uploadsInFlight[cacheKey];
        if (inFlight != null) {
          final uploaded = await inFlight;
          result.add(uploaded);
          onProgress?.call(
            CaseAttachmentProgress(
              localId: attachment.localId,
              state: CaseAttachmentUploadState.uploaded,
              objectRef: uploaded.objectRef,
            ),
          );
          continue;
        }
        final upload = _evidenceUploader
            .upload(
              attachment: attachment,
              operationId: operationId,
              onProgress: onProgress,
            )
            .then((item) {
              _uploaded[cacheKey] = item;
              return item;
            });
        _uploadsInFlight[cacheKey] = upload;
        final uploaded = await upload;
        result.add(uploaded);
      } on CaseEvidenceUploadException catch (error) {
        // No message: the screen renders the failure kind, never repo prose.
        onProgress?.call(
          CaseAttachmentProgress(
            localId: attachment.localId,
            state: CaseAttachmentUploadState.failed,
          ),
        );
        throw SupportRepositoryException.classified(
          error.offline ? SupportFailure.network : SupportFailure.upload,
          message: error.message,
          appFailure: error.appFailure,
        );
      } finally {
        _uploadsInFlight.remove(cacheKey);
      }
    }
    return result;
  }

  Future<SupportTicket?> _fetchAfterConflict(String ticketId) async {
    try {
      return (await fetchInitialThread(ticketId)).ticket;
    } on SupportRepositoryException {
      return null;
    }
  }

  SupportTicket? _ticketFromConflict(Object? raw) {
    if (raw is! Map) return null;
    final candidate = raw['ticket'] ?? raw['current'] ?? raw['resource'];
    if (candidate is Map) {
      return _ticket(Map<String, dynamic>.from(candidate), fallbackId: '');
    }
    if (raw['id'] is String || raw['ticketId'] is String) {
      return _ticket(Map<String, dynamic>.from(raw), fallbackId: '');
    }
    return null;
  }

  String? _existingCaseId(Object? raw) {
    if (raw is! Map) return null;
    for (final key in const <String>[
      'existingCaseId',
      'existingTicketId',
      'ticketId',
      'caseId',
    ]) {
      final value = _str(raw[key]);
      if (value != null) return value;
    }
    return _existingCaseId(raw['extensions'] ?? raw['data']);
  }

  SupportTicket _ticket(
    Map<String, dynamic> data, {
    required String fallbackId,
    bool excludeInitialRequest = true,
    bool includeMessages = true,
  }) {
    final attachments = _attachments(data['attachments']);
    final repliesRaw = data['replies'] ?? data['messages'] ?? data['thread'];
    final messagesAreThread = data['replies'] == null;
    return SupportTicket(
      id: _str(data['id'] ?? data['ticketId']) ?? fallbackId,
      ticketNumber: _str(data['ticketNumber'] ?? data['ticket_number']),
      status: _str(data['status']) ?? 'pending',
      category: _str(data['category']),
      subject: _str(data['subject']),
      body: _str(data['body'] ?? data['description']),
      orderRef: _str(data['orderRef'] ?? data['orderId']),
      version: _int(data['version']) ?? 0,
      createdAt: _str(data['createdAt'] ?? data['created_at']),
      updatedAt: _str(data['updatedAt'] ?? data['updated_at']),
      attachments: attachments,
      replies: includeMessages
          ? _replies(
              repliesRaw,
              excludeInitialRequest: messagesAreThread && excludeInitialRequest,
              initialBody: _str(data['body'] ?? data['description']),
            )
          : const <SupportReply>[],
      isPartial:
          data['partialEvidence'] == true ||
          _str(data['evidenceCompleteness']) == 'partial' ||
          attachments.any((item) => item.failed),
    );
  }

  List<SupportReply> _replies(
    Object? raw, {
    required bool excludeInitialRequest,
    required String? initialBody,
  }) {
    if (raw is! List) return const <SupportReply>[];
    final replies = <SupportReply>[];
    var initialRequestSkipped = !excludeInitialRequest;
    for (final entry in raw.indexed) {
      final data = entry.$2;
      if (data is! Map) continue;
      final messageType = _str(data['messageType'] ?? data['type']);
      if (messageType?.toLowerCase() == 'internal_note') continue;
      final body = _str(data['body'] ?? data['message']) ?? '';
      if (!initialRequestSkipped) {
        initialRequestSkipped = true;
        if (initialBody == null || body == initialBody) continue;
      }
      final actor = data['actor'];
      final actorRole = actor is Map ? _str(actor['role']) : null;
      replies.add(
        SupportReply(
          id:
              _str(data['messageId'] ?? data['id'] ?? data['replyId']) ??
              'reply-${entry.$1}',
          body: body,
          authorRole:
              actorRole ??
              _str(data['authorRole'] ?? data['senderRole']) ??
              'support',
          createdAt: _str(data['createdAt'] ?? data['created_at']) ?? '',
          attachments: _attachments(data['attachments']),
        ),
      );
    }
    return replies;
  }

  List<SupportAttachment> _attachments(Object? raw) {
    if (raw is! List) return const <SupportAttachment>[];
    return raw.indexed
        .map((entry) {
          final value = entry.$2;
          if (value is String) {
            return SupportAttachment(
              id: value,
              kind: 'file',
              status: 'uploaded',
              objectRef: value,
            );
          }
          if (value is! Map) {
            return SupportAttachment(
              id: 'attachment-${entry.$1}',
              kind: 'file',
              status: 'unknown',
            );
          }
          return SupportAttachment(
            id:
                _str(value['id'] ?? value['attachmentId']) ??
                'attachment-${entry.$1}',
            kind: _str(value['kind'] ?? value['type']) ?? 'file',
            status:
                _str(value['status'] ?? value['uploadStatus']) ?? 'uploaded',
            fileName: _str(
              value['fileName'] ?? value['file_name'] ?? value['name'],
            ),
            objectRef: _str(
              value['cdnRef'] ??
                  value['objectRef'] ??
                  value['object_ref'] ??
                  value['url'],
            ),
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _body(Map<String, dynamic>? raw) {
    final data = raw ?? const <String, dynamic>{};
    final nested = data['ticket'];
    return nested is Map ? Map<String, dynamic>.from(nested) : data;
  }

  String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _int(Object? value) => value is num ? value.toInt() : null;

  SupportFailure _map(DioException error) {
    final code = error.response?.statusCode;
    if (code == 401 || code == 403) return SupportFailure.unauthorized;
    if (code == 404) return SupportFailure.notFound;
    if (code == 409 || code == 412) return SupportFailure.conflict;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => SupportFailure.network,
      _ => SupportFailure.unknown,
    };
  }
}
