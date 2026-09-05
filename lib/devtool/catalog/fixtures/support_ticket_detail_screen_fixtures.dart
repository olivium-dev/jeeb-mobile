// Designed states for `SupportTicketDetailScreen` — the thread had no fixture
// file, so every rung it can reach is seeded here.

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/case_evidence/domain/case_evidence.dart';
import '../../../features/support/domain/support_repository.dart';

/// The canonical seeded thread every non-error state renders.
const SupportTicket kSupportThreadSeedTicket = SupportTicket(
  id: 'ticket-preview-001',
  ticketNumber: 'SUP-4821',
  status: 'pending',
  version: 3,
  body: 'My delivery arrived with the box crushed.',
  createdAt: '2026-08-05T09:00:00Z',
  replies: <SupportReply>[
    SupportReply(
      id: 'reply-1',
      body: 'Thanks — we are checking with the courier now.',
      authorRole: 'support',
      createdAt: '2026-08-05T10:00:00Z',
    ),
  ],
);

/// Answers every read with one canned thread.
class SupportThreadScreenCannedRepository
    implements SupportRepository, SupportThreadRepository {
  const SupportThreadScreenCannedRepository([
    this.ticket = kSupportThreadSeedTicket,
  ]);

  final SupportTicket ticket;

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async => ticket;

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async => ticket;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async => ticket;
}

/// A read that never completes — the `support_thread_loading` rung.
class SupportThreadScreenPendingRepository
    implements SupportRepository, SupportThreadRepository {
  const SupportThreadScreenPendingRepository();

  @override
  Future<SupportTicket> fetchTicket(String ticketId) =>
      Completer<SupportTicket>().future;

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) => Completer<SupportTicket>().future;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) =>
      Completer<SupportTicket>().future;
}

/// Fails every read with one classified failure — the offline / error / exit
/// rungs all arrive through this one class.
class SupportThreadScreenFailingRepository
    implements SupportRepository, SupportThreadRepository {
  const SupportThreadScreenFailingRepository(this.failure, this.appFailure);

  final SupportFailure failure;
  final AppFailure appFailure;

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async =>
      throw SupportRepositoryException.classified(
        failure,
        appFailure: appFailure,
      );

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async => throw SupportRepositoryException.classified(
    failure,
    appFailure: appFailure,
  );

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      throw SupportRepositoryException.classified(
        failure,
        appFailure: appFailure,
      );
}

/// The first read lands, every read after it fails — WP7-N5's warm failure,
/// where the messages must stay on screen.
class SupportThreadScreenRefreshFailingRepository
    implements SupportRepository, SupportThreadRepository {
  SupportThreadScreenRefreshFailingRepository([
    this.ticket = kSupportThreadSeedTicket,
  ]);

  final SupportTicket ticket;
  int fetches = 0;

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    fetches += 1;
    if (fetches == 1) return ticket;
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
  }) async => ticket;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async => ticket;
}

/// A paginated thread whose next page always fails — EP-14's retry rung.
class SupportThreadScreenPaginationFailingRepository
    implements
        SupportRepository,
        SupportThreadRepository,
        PaginatedSupportThreadRepository {
  const SupportThreadScreenPaginationFailingRepository();

  @override
  Future<SupportThreadPage> fetchInitialThread(
    String ticketId, {
    int limit = 20,
  }) async => const SupportThreadPage(
    ticket: kSupportThreadSeedTicket,
    nextCursor: 'opaque:page+2',
  );

  @override
  Future<SupportThreadPage> fetchMessages(
    String ticketId, {
    String? cursor,
    int limit = 20,
    String? initialRequestBody,
  }) async => throw const SupportRepositoryException.classified(
    SupportFailure.unknown,
    appFailure: ServerFailure(status: 500),
  );

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async =>
      kSupportThreadSeedTicket;

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async => kSupportThreadSeedTicket;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      kSupportThreadSeedTicket;
}

/// The designed states the catalog mounts.
abstract final class SupportTicketDetailScreenFixtures {
  /// The `/support/tickets/:id` path parameter every state stands for.
  static const String ticketId = 'ticket-preview-001';

  /// The cold read, held open.
  static SupportRepository get loading =>
      const SupportThreadScreenPendingRepository();

  /// A thread that is not there — exit CTA, never Retry.
  static SupportRepository get notFound =>
      const SupportThreadScreenFailingRepository(
        SupportFailure.notFound,
        NotFoundFailure(),
      );

  /// A real transport gap — the ONLY state allowed to say "offline".
  static SupportRepository get offline =>
      const SupportThreadScreenFailingRepository(
        SupportFailure.network,
        NetworkFailure(offline: true),
      );

  /// A loaded thread whose refresh then fails — the rows stay.
  static SupportRepository get refreshFailure =>
      SupportThreadScreenRefreshFailingRepository();

  /// A next page that fails — the pagination note plus its retry.
  static SupportRepository get paginationFailure =>
      const SupportThreadScreenPaginationFailingRepository();

  /// A pending thread with no replies yet.
  static SupportRepository get emptyReplies =>
      const SupportThreadScreenCannedRepository(
        SupportTicket(
          id: ticketId,
          ticketNumber: 'SUP-4822',
          status: 'pending',
          version: 1,
          body: 'Please help with this order.',
          createdAt: '2026-08-05T09:00:00Z',
        ),
      );

  /// A closed thread — read-only, no composer.
  static SupportRepository get closed =>
      const SupportThreadScreenCannedRepository(
        SupportTicket(
          id: ticketId,
          ticketNumber: 'SUP-4823',
          status: 'closed',
          version: 4,
          body: 'The parcel never arrived.',
          createdAt: '2026-08-01T09:00:00Z',
          replies: <SupportReply>[
            SupportReply(
              id: 'reply-9',
              body: 'We refunded the delivery fee. Closing this ticket.',
              authorRole: 'support',
              createdAt: '2026-08-02T11:00:00Z',
            ),
          ],
        ),
      );

  /// The healthy thread.
  static SupportRepository get loaded =>
      const SupportThreadScreenCannedRepository();
}
