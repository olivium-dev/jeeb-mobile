import '../domain/chat_message.dart';

/// Persistent, ordered queue of outbound chat messages awaiting delivery.
///
/// Implementations must preserve FIFO ordering and survive process restart.
/// The cubit drains the queue on (re)connect and re-enqueues only on
/// transport failure — server-rejected messages get marked `failed`
/// in-place via [markFailed].
abstract class ChatOutbox {
  /// Hydrate from the underlying store. Cheap to call multiple times — the
  /// implementation may cache.
  Future<List<ChatMessage>> load();

  /// Append a brand-new pending message to the tail of the queue.
  Future<void> enqueue(ChatMessage message);

  /// Remove a message by its client id once the server has acked it.
  Future<void> remove(String clientId);

  /// Update the persisted copy (status / attempts / serverId). No-op if the
  /// id is not in the queue.
  Future<void> update(ChatMessage message);

  /// Mark a message permanently failed without removing it — surfaces in
  /// the UI as a retry-able badge.
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
