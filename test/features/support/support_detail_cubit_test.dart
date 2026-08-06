import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/features/support/application/support_detail_cubit.dart';
import 'package:jeeb_mobile/features/support/application/support_detail_state.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';

const _firstOperationId = '123e4567-e89b-42d3-a456-426614174000';
const _nextOperationId = '223e4567-e89b-42d3-a456-426614174000';

void main() {
  test(
    'stale reply keeps its body, evidence, and UUID for a versioned retry',
    () async {
      final repository = _ConflictThenSuccessRepository();
      var factoryCalls = 0;
      final cubit = SupportDetailCubit(
        repository: repository,
        ticketId: 'ticket-1',
        operationIdFactory: () =>
            factoryCalls++ == 0 ? _firstOperationId : _nextOperationId,
      );
      addTearDown(cubit.close);

      await cubit.load();
      cubit.setReplyBody('The issue is still happening.');
      cubit.addAttachment('proof.jpg', bytes: <int>[1, 2, 3]);
      await cubit.sendReply();

      expect(cubit.state.phase, SupportDetailPhase.conflict);
      expect(cubit.state.ticket?.version, 2);
      expect(cubit.state.replyBody, 'The issue is still happening.');
      expect(cubit.state.attachmentPaths, <String>['proof.jpg']);
      expect(cubit.state.operationId, _firstOperationId);
      expect(repository.drafts.first.operationId, _firstOperationId);
      expect(repository.drafts.first.version, 1);

      await cubit.sendReply();

      expect(repository.drafts, hasLength(2));
      expect(repository.drafts.last.operationId, _firstOperationId);
      expect(repository.drafts.last.version, 2);
      expect(cubit.state.phase, SupportDetailPhase.loaded);
      expect(cubit.state.ticket?.version, 3);
      expect(cubit.state.replyBody, isEmpty);
      expect(cubit.state.attachmentPaths, isEmpty);
      expect(cubit.state.operationId, _nextOperationId);
    },
  );

  test(
    'loads stable nextCursor pages incrementally without duplicates',
    () async {
      final repository = _PaginatedRepository();
      final cubit = SupportDetailCubit(
        repository: repository,
        ticketId: 'ticket-1',
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.nextCursor, 'opaque:next+1');
      expect(cubit.state.ticket?.replies.map((item) => item.id), <String>[
        'reply-2',
      ]);

      await cubit.loadMore();

      expect(repository.cursors, <String?>[null, 'opaque:next+1']);
      expect(cubit.state.nextCursor, isNull);
      expect(cubit.state.ticket?.replies.map((item) => item.id), <String>[
        'reply-1',
        'reply-2',
      ]);
    },
  );
}

class _ConflictThenSuccessRepository implements SupportThreadRepository {
  int attempts = 0;
  final List<SupportReplyDraft> drafts = <SupportReplyDraft>[];

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    return const SupportTicket(
      id: 'ticket-1',
      status: 'pending',
      version: 1,
      body: 'Original request',
    );
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    drafts.add(draft);
    attempts++;
    if (attempts == 1) {
      throw const SupportRepositoryException(
        SupportFailure.conflict,
        'stale',
        SupportTicket(
          id: 'ticket-1',
          status: 'pending',
          version: 2,
          body: 'Original request',
          replies: <SupportReply>[
            SupportReply(
              id: 'support-1',
              body: 'Can you send a photo?',
              authorRole: 'support',
              createdAt: '2026-08-05T09:00:00Z',
            ),
          ],
        ),
      );
    }
    return const SupportTicket(
      id: 'ticket-1',
      status: 'pending',
      version: 3,
      body: 'Original request',
      replies: <SupportReply>[
        SupportReply(
          id: 'user-1',
          body: 'The issue is still happening.',
          authorRole: 'user',
          createdAt: '2026-08-05T10:00:00Z',
        ),
      ],
    );
  }
}

class _PaginatedRepository
    implements SupportThreadRepository, PaginatedSupportThreadRepository {
  final List<String?> cursors = <String?>[];

  @override
  Future<SupportThreadPage> fetchInitialThread(
    String ticketId, {
    int limit = 20,
  }) async {
    cursors.add(null);
    return const SupportThreadPage(
      nextCursor: 'opaque:next+1',
      ticket: SupportTicket(
        id: 'ticket-1',
        status: 'pending',
        version: 2,
        body: 'Original request',
        replies: <SupportReply>[
          SupportReply(
            id: 'reply-2',
            body: 'Newest reply',
            authorRole: 'support',
            createdAt: '2026-08-05T10:00:00Z',
          ),
        ],
      ),
    );
  }

  @override
  Future<SupportThreadPage> fetchMessages(
    String ticketId, {
    String? cursor,
    int limit = 20,
    String? initialRequestBody,
  }) async {
    cursors.add(cursor);
    return const SupportThreadPage(
      ticket: SupportTicket(
        id: 'ticket-1',
        status: 'pending',
        version: 2,
        replies: <SupportReply>[
          SupportReply(
            id: 'reply-1',
            body: 'Earlier reply',
            authorRole: 'support',
            createdAt: '2026-08-05T09:00:00Z',
          ),
          SupportReply(
            id: 'reply-2',
            body: 'Duplicate latest reply',
            authorRole: 'support',
            createdAt: '2026-08-05T10:00:00Z',
          ),
        ],
      ),
    );
  }

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    return (await fetchInitialThread(ticketId)).ticket;
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }
}
