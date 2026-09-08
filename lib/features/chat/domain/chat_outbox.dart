import '../domain/chat_message.dart';

abstract interface class AccountScopedChatOutbox {
  ChatOutbox forAccount(String userId);
}

abstract class ChatOutbox {
  Future<List<ChatMessage>> load();

  Future<void> enqueue(ChatMessage message);

  Future<void> remove(String clientId);

  Future<void> update(ChatMessage message);

  Future<void> markFailed(String clientId) async {
    final all = await load();
    final hit = all
        .where((m) => m.clientId == clientId)
        .cast<ChatMessage?>()
        .firstWhere((_) => true, orElse: () => null);
    if (hit == null) return;
    await update(hit.copyWith(status: ChatMessageStatus.failed));
  }
}
