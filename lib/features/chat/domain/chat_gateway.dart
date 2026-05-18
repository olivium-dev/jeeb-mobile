import 'dart:async';

import 'delivery_chat_message.dart';

/// Outbound contract for chat transport. The cubit handles optimistic UI
/// (every outgoing message lands as [MessageStatus.sending] immediately and
/// then transitions on the gateway's acknowledgement), so the gateway only
/// owns the network/round-trip — never the in-memory list.
///
/// The MVP build wires this to [InMemoryChatGateway] which echoes a single
/// canned reply per outgoing message so the chat screen can be demoed end to
/// end without any real backend. The Dio-backed [DioChatGateway] points the
/// same interface at the mock backend (or, in prod, `jeeb-gateway`) via the
/// chat-service + offer-service routes.
///
/// The first positional argument is named [conversationId] in the new chat
/// flow; it stays compatible with the older photo-chat call sites that pass
/// a delivery id because both ids are opaque strings to the gateway.
abstract class ChatGateway {
  /// History of messages previously exchanged on this thread. Returned newest
  /// last so the cubit can append without sorting.
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId);

  /// Conversation phase ([ConversationPhase.broadcasting] / `accepted` /
  /// `closed`) the cubit needs to render the right UI shell (composer on/off,
  /// offer-card list vs 1:1 timeline). Optional — gateways that don't carry
  /// a phase (the MVP in-memory echo) can return [ConversationPhase.accepted]
  /// to retain the existing 1:1 behaviour.
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  /// Push an outgoing message. Returns the same message with its status
  /// promoted to at-least [MessageStatus.sent]; the caller swaps the optimistic
  /// entry for this one. Throwing surfaces as [MessageStatus.failed] on the
  /// optimistic entry.
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  );

  /// Stream of inbound events for this thread — incoming messages from the
  /// counterpart, delivered receipts, read receipts, and (post-accept) phase
  /// transitions.
  Stream<ChatEvent> subscribe(String conversationId);

  /// Accept a Jeeber's offer from inside the broadcasting chat. Drives the
  /// offer-service saga (winning offer accepted, losers superseded, phase
  /// flipped, system message appended). The gateway is responsible for the
  /// HTTP call; the cubit re-fetches history + phase once this resolves.
  Future<void> acceptOffer(String conversationId, String offerId) async {}
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
  final DeliveryChatMessage message;
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

/// The conversation flipped phase (e.g. `broadcasting → accepted` after the
/// client accepted an offer). The cubit re-derives composer visibility and
/// re-fetches history so the system message is visible.
class PhaseChanged extends ChatEvent {
  const PhaseChanged(this.phase);
  final ConversationPhase phase;
}
