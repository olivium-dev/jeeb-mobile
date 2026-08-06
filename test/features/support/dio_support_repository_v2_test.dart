import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/features/support/application/support_detail_cubit.dart';
import 'package:jeeb_mobile/features/support/data/dio_support_repository.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';

const _operationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  test(
    'ticket retry reuses its UUID and already-uploaded attachment',
    () async {
      final adapter = _SupportAdapter(failFirstCreate: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = adapter;
      final uploader = _FakeUploader();
      final repository = DioSupportRepository(dio, evidenceUploader: uploader);
      final draft = SupportTicketDraft(
        category: SupportCategory.delivery,
        body: 'I need help with this delivery.',
        orderRef: 'delivery-1',
        operationId: _operationId,
        attachments: <CaseAttachmentDraft>[
          CaseAttachmentDraft(
            localId: 'photo-1',
            fileName: 'proof.jpg',
            contentType: 'image/jpeg',
            kind: CaseAttachmentKind.photo,
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      );

      await expectLater(
        repository.submitTicketV2(draft),
        throwsA(
          isA<SupportRepositoryException>().having(
            (error) => error.failure,
            'failure',
            SupportFailure.network,
          ),
        ),
      );
      final ticket = await repository.submitTicketV2(draft);

      expect(ticket.id, 'ticket-1');
      expect(ticket.canonicalStatus, SupportTicketStatus.pending);
      expect(uploader.calls, 1);
      expect(adapter.createPaths, <String>[
        '/v1/support/tickets',
        '/v1/support/tickets',
      ]);
      expect(adapter.createKeys, everyElement(_operationId));
      expect(
        adapter.createBodies.map((body) => body['operationId']),
        everyElement(_operationId),
      );
      final attachments = adapter.createBodies.last['attachments'] as List;
      expect(attachments, <String>['case-evidence/photo-1']);
    },
  );

  test(
    '412 reply conflict fetches the latest version for a safe retry',
    () async {
      final adapter = _SupportAdapter(staleReply: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = adapter;
      final repository = DioSupportRepository(
        dio,
        evidenceUploader: _FakeUploader(),
      );

      try {
        await repository.replyToTicket(
          'ticket-1',
          SupportReplyDraft(
            operationId: _operationId,
            body: 'Here is the requested detail.',
            version: 2,
            attachments: <CaseAttachmentDraft>[
              CaseAttachmentDraft(
                localId: 'reply-photo',
                fileName: 'reply.jpg',
                contentType: 'image/jpeg',
                kind: CaseAttachmentKind.photo,
                bytes: Uint8List.fromList(<int>[4, 5, 6]),
              ),
            ],
          ),
        );
        fail('Expected a stale-version conflict.');
      } on SupportRepositoryException catch (error) {
        expect(error.failure, SupportFailure.conflict);
        expect(error.latestTicket?.version, 3);
        expect(error.latestTicket?.replies.single.body, 'Latest support reply');
        expect(error.latestTicket?.replies.single.authorRole, 'support');
        expect(
          error.latestTicket?.replies.single.attachments.single.objectRef,
          'support/reply-1.jpg',
        );
      }

      expect(adapter.replyPaths, <String>[
        '/v1/support/tickets/ticket-1/reply',
      ]);
      expect(adapter.replyKeys.single, _operationId);
      expect(adapter.ifMatch.single, '2');
      expect(adapter.replyBodies.single['expectedVersion'], 2);
      expect(adapter.replyBodies.single.containsKey('version'), isFalse);
      expect(adapter.replyBodies.single['attachments'], <String>[
        'case-evidence/reply-photo',
      ]);
      expect(adapter.fetchPaths, <String>['/v1/support/tickets/ticket-1']);
      expect(adapter.messagePaths, <String>[
        '/v1/support/tickets/ticket-1/messages',
      ]);
      expect(
        <String>[
          ...adapter.createPaths,
          ...adapter.replyPaths,
          ...adapter.fetchPaths,
          ...adapter.messagePaths,
        ].any((path) => path.contains('service')),
        isFalse,
      );
    },
  );

  test('ticket create conflict recovers using existingCaseId', () async {
    final adapter = _SupportAdapter(conflictCreate: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    final repository = DioSupportRepository(
      dio,
      evidenceUploader: _FakeUploader(),
    );

    final ticket = await repository.submitTicketV2(
      const SupportTicketDraft(
        category: SupportCategory.other,
        body: 'Please help with this account issue.',
        operationId: _operationId,
      ),
    );

    expect(ticket.id, 'ticket-existing');
    expect(ticket.version, 3);
    expect(ticket.replies.single.id, 'reply-1');
    expect(adapter.fetchPaths, <String>['/v1/support/tickets/ticket-existing']);
    expect(adapter.messagePaths, <String>[
      '/v1/support/tickets/ticket-existing/messages',
    ]);
  });

  test('ticket message pages preserve the opaque nextCursor', () async {
    final adapter = _SupportAdapter(paginated: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    final repository = DioSupportRepository(
      dio,
      evidenceUploader: _FakeUploader(),
    );

    final first = await repository.fetchInitialThread('ticket-1');
    final second = await repository.fetchMessages(
      'ticket-1',
      cursor: first.nextCursor,
    );

    expect(first.nextCursor, 'opaque:page+2');
    expect(first.ticket.replies.map((item) => item.id), <String>['reply-2']);
    expect(second.nextCursor, isNull);
    expect(second.ticket.replies.map((item) => item.id), <String>['reply-1']);
    expect(adapter.fetchPaths, <String>['/v1/support/tickets/ticket-1']);
    expect(adapter.messagePaths, <String>[
      '/v1/support/tickets/ticket-1/messages',
      '/v1/support/tickets/ticket-1/messages',
    ]);
    expect(adapter.messageCursors, <String?>[null, 'opaque:page+2']);
    expect(adapter.messageLimits, <int?>[20, 20]);
  });

  test(
    'gateway newest-window contract shows the latest 20 before loading older replies',
    () async {
      final adapter = _SupportAdapter(largeThread: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = adapter;
      final repository = DioSupportRepository(
        dio,
        evidenceUploader: _FakeUploader(),
      );
      final cubit = SupportDetailCubit(
        repository: repository,
        ticketId: 'ticket-1',
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.ticket?.replies, hasLength(20));
      expect(cubit.state.ticket?.replies.map((item) => item.id), <String>[
        for (var index = 6; index <= 25; index++) 'reply-$index',
      ]);
      expect(cubit.state.nextCursor, 'older:reply-6');
      expect(adapter.messageCursors, <String?>[null]);

      await cubit.loadMore();

      expect(cubit.state.ticket?.replies, hasLength(25));
      expect(cubit.state.ticket?.replies.map((item) => item.id), <String>[
        for (var index = 1; index <= 25; index++) 'reply-$index',
      ]);
      expect(
        cubit.state.ticket?.replies.any((item) => item.id == 'initial-1'),
        isFalse,
      );
      expect(cubit.state.nextCursor, isNull);
      expect(adapter.messageCursors, <String?>[null, 'older:reply-6']);
      expect(adapter.messageLimits, <int?>[20, 20]);
    },
  );
}

class _FakeUploader implements CaseEvidenceUploader {
  int calls = 0;

  @override
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    calls++;
    return UploadedCaseAttachment(
      localId: attachment.localId,
      objectRef: 'case-evidence/${attachment.localId}',
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      kind: attachment.kind,
    );
  }
}

class _SupportAdapter implements HttpClientAdapter {
  _SupportAdapter({
    this.failFirstCreate = false,
    this.conflictCreate = false,
    this.staleReply = false,
    this.paginated = false,
    this.largeThread = false,
  });

  final bool failFirstCreate;
  final bool conflictCreate;
  final bool staleReply;
  final bool paginated;
  final bool largeThread;
  final List<String> createPaths = <String>[];
  final List<String?> createKeys = <String?>[];
  final List<Map<String, dynamic>> createBodies = <Map<String, dynamic>>[];
  final List<String> replyPaths = <String>[];
  final List<String?> replyKeys = <String?>[];
  final List<String?> ifMatch = <String?>[];
  final List<Map<String, dynamic>> replyBodies = <Map<String, dynamic>>[];
  final List<String> fetchPaths = <String>[];
  final List<String> messagePaths = <String>[];
  final List<String?> messageCursors = <String?>[];
  final List<int?> messageLimits = <int?>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path == '/v1/support/tickets') {
      createPaths.add(options.path);
      createKeys.add(options.headers['Idempotency-Key'] as String?);
      createBodies.add(Map<String, dynamic>.from(options.data as Map));
      if (failFirstCreate && createPaths.length == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      if (conflictCreate) {
        return _json(const <String, Object?>{
          'existingCaseId': 'ticket-existing',
        }, status: 409);
      }
      return _json(<String, Object?>{
        'id': 'ticket-1',
        'status': 'pending',
        'version': 1,
      }, status: 201);
    }
    if (options.method == 'POST' && options.path.endsWith('/reply')) {
      replyPaths.add(options.path);
      replyKeys.add(options.headers['Idempotency-Key'] as String?);
      ifMatch.add(options.headers['If-Match'] as String?);
      replyBodies.add(Map<String, dynamic>.from(options.data as Map));
      if (staleReply) {
        return _json(const <String, Object?>{
          'message': 'stale',
          'existingCaseId': 'ticket-1',
        }, status: 412);
      }
    }
    if (options.method == 'GET' &&
        (options.path == '/v1/support/tickets/ticket-1' ||
            options.path == '/v1/support/tickets/ticket-existing')) {
      fetchPaths.add(options.path);
      return _json(<String, Object?>{
        'id': options.path.endsWith('ticket-existing')
            ? 'ticket-existing'
            : 'ticket-1',
        'status': 'pending',
        'version': 3,
        'body': 'Original request',
      });
    }
    if (options.method == 'GET' && options.path.endsWith('/messages')) {
      messagePaths.add(options.path);
      final cursor = options.queryParameters['cursor'] as String?;
      messageCursors.add(cursor);
      messageLimits.add(options.queryParameters['limit'] as int?);
      if (largeThread) {
        final firstPage = cursor == null;
        return _json(<String, Object?>{
          'items': <Object?>[
            if (!firstPage)
              <String, Object?>{
                'messageId': 'initial-1',
                'body': 'Original request',
                'messageType': 'message',
                'actor': <String, Object?>{'role': 'client'},
                'createdAt': '2026-08-05T08:00:00Z',
              },
            for (
              var index = firstPage ? 6 : 1;
              index <= (firstPage ? 25 : 5);
              index++
            )
              <String, Object?>{
                'messageId': 'reply-$index',
                'body': 'Reply $index',
                'messageType': 'message',
                'actor': <String, Object?>{'role': 'support'},
                'createdAt': DateTime.utc(
                  2026,
                  8,
                  5,
                  8,
                  index,
                ).toIso8601String(),
              },
          ],
          'nextCursor': firstPage ? 'older:reply-6' : null,
        });
      }
      if (paginated && cursor != null) {
        return _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'messageId': 'reply-1',
              'messageType': 'message',
              'body': 'Earlier reply',
              'actor': <String, Object?>{'role': 'support'},
              'createdAt': '2026-08-05T09:00:00Z',
            },
          ],
          'nextCursor': null,
        });
      }
      return _json(<String, Object?>{
        'items': <Object?>[
          if (!paginated)
            <String, Object?>{
              'messageId': 'initial-1',
              'body': 'Original request',
              'messageType': 'message',
              'actor': <String, Object?>{'role': 'client'},
              'createdAt': '2026-08-05T09:00:00Z',
            },
          <String, Object?>{
            'messageId': paginated ? 'reply-2' : 'reply-1',
            'body': paginated ? 'Newest reply' : 'Latest support reply',
            'messageType': 'message',
            'actor': <String, Object?>{'role': 'support'},
            'createdAt': '2026-08-05T10:00:00Z',
            'attachments': <Object?>[
              <String, Object?>{
                'attachmentId': 'attachment-1',
                'cdnRef': 'support/reply-1.jpg',
                'fileName': 'reply.jpg',
              },
            ],
          },
          <String, Object?>{
            'messageId': 'note-1',
            'body': 'Internal only',
            'messageType': 'internal_note',
            'actor': <String, Object?>{'role': 'admin'},
            'createdAt': '2026-08-05T10:01:00Z',
          },
        ],
        'nextCursor': paginated ? 'opaque:page+2' : null,
      });
    }
    return _json(const <String, Object?>{});
  }
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
