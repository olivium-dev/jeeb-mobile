import 'dart:async';

import 'chat_message.dart';

/// Outbound contract for chat transport. The cubit handles optimistic UI
/// (every outgoing message lands as [MessageStatus.sending] immediately and
/// then transitions on the gateway's acknowledgement), so the gateway only
/// owns the network/round-trip — never the in-memory list.
///
/// The MVP build wires this to [InMemoryChatGateway] which echoes a single
/// canned reply per outgoing message so the chat screen can be demoed end to
/// end without any real backend. A future task swaps the binding to a real
/// `chat-service` client through `jeeb-gateway` (see JEEB-BOUNDARIES.md §5).
abstract class ChatGateway {
  /// History of messages previously exchanged on this thread. Returned newest
  /// last so the cubit can append without sorting.
  Future<List<ChatMessage>> loadHistory(String deliveryId);

  /// Push an outgoing message. Returns the same message with its status
  /// promoted to at-least [MessageStatus.sent]; the caller swaps the optimistic
  /// entry for this one. Throwing surfaces as [MessageStatus.failed] on the
  /// optimistic entry.
  Future<ChatMessage> send(String deliveryId, ChatMessage message);

  /// Stream of inbound events for this thread — incoming messages from the
  /// counterpart, delivered receipts, and read receipts.
  Stream<ChatEvent> subscribe(String deliveryId);
}

/// Closed union of inbound chat events. Kept as a sealed-style hierarchy so
/// the cubit can `switch` on the runtime type without needing a discriminator
/// field.
sealed class ChatEvent {
  const ChatEvent();
}

/// A new message arrived from the counterpart.
class IncomingMessage extends ChatEvent {
  const IncomingMessage(this.message);
  final ChatMessage message;
}

/// The counterpart's device confirmed delivery for [messageId].
/// Promotes its status from [MessageStatus.sent] to [MessageStatus.delivered].
class DeliveryReceipt extends ChatEvent {
  const DeliveryReceipt(this.messageId);
  final String messageId;
}

/// The counterpart's device acknowledged read for everything up to and
/// including [throughMessageId]. The cubit walks back through its outgoing
/// queue and promotes anything still in [MessageStatus.sent]/[delivered].
class ReadReceipt extends ChatEvent {
  const ReadReceipt(this.throughMessageId);
  final String throughMessageId;
}
