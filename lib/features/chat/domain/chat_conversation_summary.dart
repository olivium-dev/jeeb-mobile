import 'package:equatable/equatable.dart';

import '../../order_history/domain/order_summary.dart' show OrderRequestStatus;

/// One row of the chat inbox. [title] stays null when the gateway sent none:
/// the fallback is a localized string the row picks at render time.
class ChatConversationSummary extends Equatable {
  const ChatConversationSummary({
    required this.requestId,
    required this.conversationId,
    required this.status,
    this.title,
    this.tier = '',
  });

  final String requestId;

  /// Often EMPTY on the live gateway row — never a reason to drop the row.
  final String conversationId;

  final String? title;

  final OrderRequestStatus status;

  final String tier;

  /// Chat-detail route id: prefer the request id, which the detail screen
  /// resolves by correlation key.
  String get chatRouteId => requestId.isNotEmpty ? requestId : conversationId;

  @override
  List<Object?> get props => <Object?>[
        requestId,
        conversationId,
        title,
        status,
        tier,
      ];
}

/// A page of inbox rows plus the count of rows that carried NEITHER id and so
/// could not be routed — surfaced as a partial-load note, never swallowed.
class ChatConversationsPage extends Equatable {
  const ChatConversationsPage({
    required this.conversations,
    this.skippedRows = 0,
  });

  static const ChatConversationsPage empty = ChatConversationsPage(
    conversations: <ChatConversationSummary>[],
  );

  final List<ChatConversationSummary> conversations;

  final int skippedRows;

  @override
  List<Object?> get props => <Object?>[conversations, skippedRows];
}

/// Read contract for the chat inbox. [fetchConversations] throws an
/// `AppFailure` — an empty page NEVER means "the read failed".
abstract class ChatConversationsRepository {
  Future<ChatConversationsPage> fetchConversations();
}
