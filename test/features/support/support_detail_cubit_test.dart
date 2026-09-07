import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
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

  test(
    'refresh() keeps the loaded thread and lands in refreshError (N5)',
    () async {
      final repository = _RefreshFailingThreadRepository();
      final cubit = SupportDetailCubit(
        repository: repository,
        ticketId: 'ticket-1',
      );
      await cubit.load();
      expect(cubit.state.phase, SupportDetailPhase.loaded);

      await cubit.refresh();

      // The phase never returns to loading, so the messages stay on screen.
      expect(cubit.state.phase, SupportDetailPhase.loaded);
      expect(cubit.state.ticket, isNotNull);
      expect(cubit.state.refreshError, isNotNull);
      expect(cubit.state.appFailure, isNull);
      cubit.acknowledgeRefreshError();
      expect(cubit.state.refreshError, isNull);
      await cubit.close();
    },
  );

  test(
    'refresh() from the conflict phase keeps the thread mounted (N5)',
    () async {
      final repository = _ConflictThenSuccessRepository();
      final cubit = SupportDetailCubit(
        repository: repository,
        ticketId: 'ticket-1',
      );
      addTearDown(cubit.close);

      await cubit.load();
      cubit.setReplyBody('The issue is still happening.');
      await cubit.sendReply();
      expect(cubit.state.phase, SupportDetailPhase.conflict);
      expect(cubit.state.ticket, isNotNull);

      // A pull-to-refresh over a stale-reply conflict must NOT go through
      // load(): `_ThreadBody` is mounted and load() would blank it.
      await cubit.refresh();

      expect(cubit.state.phase, isNot(SupportDetailPhase.loading));
      expect(
        cubit.state.ticket,
        isNotNull,
        reason: 'support_thread_request stays mounted across the refresh',
      );
      expect(cubit.state.replyBody, 'The issue is still happening.');
    },
  );

  test('a cold read failure carries the classified failure', () async {
    final cubit = SupportDetailCubit(
      repository: const _AlwaysFailingThreadRepository(),
      ticketId: 'ticket-1',
    );
    await cubit.load();

    expect(cubit.state.phase, SupportDetailPhase.failed);
    expect(cubit.state.appFailure, isA<NetworkFailure>());
    await cubit.close();
  });

  test('load() is guarded while a read is already in flight', () async {
    final repository = _PendingThreadRepository();
    final cubit = SupportDetailCubit(
      repository: repository,
      ticketId: 'ticket-1',
    );
    final first = cubit.load();
    await cubit.load();
    expect(repository.calls, 1);

    repository.complete();
    await first;
    await cubit.close();
  });
}

class _RefreshFailingThreadRepository implements SupportThreadRepository {
  int fetches = 0;

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    fetches += 1;
    if (fetches == 1) {
      return const SupportTicket(
        id: 'ticket-1',
        status: 'pending',
        version: 1,
        body: 'Original request',
      );
    }
    throw const SupportRepositoryException.classified(
      SupportFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) => throw UnimplementedError();
}

class _AlwaysFailingThreadRepository implements SupportThreadRepository {
  const _AlwaysFailingThreadRepository();

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async =>
      throw const SupportRepositoryException.classified(
        SupportFailure.network,
        appFailure: NetworkFailure(offline: true),
      );

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) => throw UnimplementedError();
}

class _PendingThreadRepository implements SupportThreadRepository {
  final Completer<SupportTicket> _held = Completer<SupportTicket>();
  int calls = 0;

  void complete() => _held.complete(
    const SupportTicket(id: 'ticket-1', status: 'pending', version: 1),
  );

  @override
  Future<SupportTicket> fetchTicket(String ticketId) {
    calls += 1;
    return _held.future;
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) => throw UnimplementedError();
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
