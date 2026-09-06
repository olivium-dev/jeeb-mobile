// Designed states for the chat inbox tab — ONE source of truth, two consumers.

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/chat/domain/chat_conversation_summary.dart';
import '../../../features/order_history/domain/order_summary.dart'
    show OrderRequestStatus;

/// Answers one canned page, or throws one canned failure. No transport.
class CannedChatConversationsRepository implements ChatConversationsRepository {
  const CannedChatConversationsRepository({this.page, this.failure})
      : assert(
          page != null || failure != null,
          'A repository that neither answers nor fails is not a state.',
        );

  final ChatConversationsPage? page;
  final AppFailure? failure;

  @override
  Future<ChatConversationsPage> fetchConversations() async {
    final AppFailure? thrown = failure;
    if (thrown != null) throw thrown;
    return page!;
  }
}

/// A read that never comes back — the tab's cold frame.
class StalledChatConversationsRepository
    implements ChatConversationsRepository {
  const StalledChatConversationsRepository();

  @override
  Future<ChatConversationsPage> fetchConversations() =>
      Completer<ChatConversationsPage>().future;
}

/// Answers the first read from [first] and every later one by throwing
/// [failure] — the only way to reach the WARM failure over rendered rows.
class RefreshFailingChatConversationsRepository
    implements ChatConversationsRepository {
  RefreshFailingChatConversationsRepository({
    required this.first,
    required this.failure,
  });

  final ChatConversationsPage first;
  final AppFailure failure;
  int reads = 0;

  @override
  Future<ChatConversationsPage> fetchConversations() async {
    reads++;
    if (reads > 1) throw failure;
    return first;
  }
}

/// The designed states of `ChatTab`.
class ChatTabPreviewFixtures {
  const ChatTabPreviewFixtures._();

  /// Three live conversations, one of them sent WITHOUT a `conversationId` —
  /// the live gateway row shape, which now survives (SHELL-02).
  static const ChatConversationsPage threeRows = ChatConversationsPage(
    conversations: <ChatConversationSummary>[
      ChatConversationSummary(
        requestId: 'req-8841',
        conversationId: 'conv-8841',
        title: 'Pharmacy run',
        status: OrderRequestStatus.enRoute,
        tier: 'flash',
      ),
      ChatConversationSummary(
        requestId: 'req-8842',
        conversationId: 'conv-8842',
        title: 'Grocery run',
        status: OrderRequestStatus.matched,
        tier: 'express',
      ),
      ChatConversationSummary(
        requestId: 'req-8843',
        conversationId: '',
        status: OrderRequestStatus.pickedUp,
        tier: 'standard',
      ),
    ],
  );

  /// The cold read, still in flight.
  static ChatConversationsRepository loading() =>
      const StalledChatConversationsRepository();

  /// A real 200 with zero rows — the honest empty inbox.
  static ChatConversationsRepository empty() =>
      const CannedChatConversationsRepository(
        page: ChatConversationsPage.empty,
      );

  /// The gateway is down. This used to read as "No conversations yet".
  static ChatConversationsRepository failed503() =>
      const CannedChatConversationsRepository(
        failure: ServerFailure(status: 503),
      );

  /// No transport at all — the one failure family allowed to blame the
  /// connection.
  static ChatConversationsRepository offline() =>
      const CannedChatConversationsRepository(
        failure: NetworkFailure(offline: true),
      );

  /// One row carried NEITHER id, so it is unroutable: the list is shortened
  /// and the tab says by how much.
  static ChatConversationsRepository partialLoad() =>
      const CannedChatConversationsRepository(
        page: ChatConversationsPage(
          conversations: <ChatConversationSummary>[
            ChatConversationSummary(
              requestId: 'req-9200',
              conversationId: 'conv-9200',
              title: 'Pharmacy run',
              status: OrderRequestStatus.enRoute,
            ),
          ],
          skippedRows: 1,
        ),
      );

  /// Rows on screen, and the re-read failed. The rows stay.
  static ChatConversationsRepository refreshFailed() =>
      RefreshFailingChatConversationsRepository(
        first: threeRows,
        failure: const ServerFailure(status: 503),
      );

  /// The happy path.
  static ChatConversationsRepository rows() =>
      const CannedChatConversationsRepository(page: threeRows);
}
