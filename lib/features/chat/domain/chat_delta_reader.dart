import 'delivery_chat_message.dart';

/// Opt-in capability for gateways that can read only rows after a server
/// cursor. Kept separate from [ChatGateway] so existing gateway doubles do not
/// acquire another required member.
abstract interface class ChatDeltaReader {
  Future<ChatHistoryBatch> loadHistorySince(
    String conversationId,
    String cursor,
  );
}

/// A decoded history response plus the wire-boundary metadata needed to advance
/// a delta cursor without reconstructing server order from the rendered list.
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

  /// Successfully decoded messages in raw server array order.
  final List<DeliveryChatMessage> messages;

  /// Id of the physical final wire row, only when that row decoded cleanly.
  ///
  /// A malformed final row deliberately produces null; callers must retain
  /// their previous cursor rather than scan backward and skip the bad row.
  final String? nextCursor;

  /// Physical rows or envelopes rejected by the decoder.
  final int malformedCount;
}
