import '../domain/chat_message.dart';
import '../domain/chat_outbox.dart';

/// Test-only [ChatOutbox]. Holds messages in a list. No persistence.
class InMemoryChatOutbox extends ChatOutbox {
  InMemoryChatOutbox([List<ChatMessage>? seed]) : _items = [...?seed];

  final List<ChatMessage> _items;

  @override
  Future<List<ChatMessage>> load() async => List.unmodifiable(_items);

  @override
  Future<void> enqueue(ChatMessage message) async {
    _items.add(message);
  }

  @override
  Future<void> remove(String clientId) async {
    _items.removeWhere((m) => m.clientId == clientId);
  }

  @override
  Future<void> update(ChatMessage message) async {
    final idx = _items.indexWhere((m) => m.clientId == message.clientId);
    if (idx == -1) return;
    _items[idx] = message;
  }
}
