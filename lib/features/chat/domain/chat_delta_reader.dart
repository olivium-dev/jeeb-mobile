import 'delivery_chat_message.dart';

abstract interface class ChatDeltaReader {
  Future<ChatHistoryBatch> loadHistorySince(
    String conversationId,
    String cursor,
  );
}

class ChatHistoryBatch {
  const ChatHistoryBatch({
    required this.messages,
    required this.nextCursor,
    required this.malformedCount,
  });

  static const empty = ChatHistoryBatch(
    messages: <DeliveryChatMessage>[],
    nextCursor: null,
    malformedCount: 0,
  );

  final List<DeliveryChatMessage> messages;

  /// Malformed final row deliberately produces null; callers must retain previous cursor.
  final String? nextCursor;

  final int malformedCount;
}
