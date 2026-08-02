import 'chat_gateway.dart';

const String kChatMessageCreatedAtField = 'CreatedAt';

/// TRAP: requires composite index (Messages, VisibleTo CONTAINS, CreatedAt DESC).
const String kChatMessageVisibleToField = 'VisibleTo';

const String kConversationsCollection = 'Conversations';
const String kMessagesSubcollection = 'Messages';

/// Listener window size (bounded, not unbounded).
const int kChatRealtimeWindow = 50;

class RealtimeDocChange {
  const RealtimeDocChange({
    required this.id,
    required this.data,
    this.removed = false,
  });

  /// Document id = HTTP message_id (enables id-dedupe).
  final String id;
  final Map<String, Object?> data;
  /// TRAP: append-only (no delete), modelled to prevent removal as arrival.
  final bool removed;
}

/// Realtime projector. Reads snapshot.docChanges and emits [IncomingMessage]
/// into [ChatGateway.subscribe] → [ChatCubit._handleEvent] (enables id-dedupe).
class ChatRealtimeProjector {
  ChatRealtimeProjector({required this.mapRow});

  /// Maps raw document to message or null. Injected for codec isolation.
  final ChatEvent? Function(RealtimeDocChange change) mapRow;

  /// Events for snapshot batch; malformed rows skipped.
  List<ChatEvent> project(Iterable<RealtimeDocChange> changes) {
    final events = <ChatEvent>[];
    for (final change in changes) {
      if (change.removed) continue;
      final event = mapRow(change);
      if (event != null) events.add(event);
    }
    return events;
  }
}

/// Realtime channel for one conversation.
abstract class ChatRealtimeSource {
  /// Opens channel; stream carries [IncomingMessage] + [RealtimeTransportChanged].
  Stream<ChatEvent> subscribe(String conversationId);

  Future<void> dispose();
}
