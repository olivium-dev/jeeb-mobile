import 'package:equatable/equatable.dart';

import 'chat_message.dart';

/// Discriminator for incoming events on the chat socket. The gateway sends
/// JSON envelopes shaped as `{ "type": "...", ...payload }`; the data layer
/// decodes them into one of these typed events before they reach the cubit.
enum ChatEventType { messageReceived, ack, typing, error, unknown }

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  ChatEventType get type;

  @override
  List<Object?> get props => const [];

  static ChatEvent fromJson(Map<String, Object?> json) {
    final wire = json['type'] as String?;
    switch (wire) {
      case 'message':
      case 'messageReceived':
        return MessageReceivedEvent(message: ChatMessage.fromJson(
          (json['message'] as Map).cast<String, Object?>(),
        ));
      case 'ack':
      case 'deliveryAck':
        return MessageAckEvent(
          clientId: json['clientId']! as String,
          serverId: json['serverId'] as String?,
          status: _statusFromAck(json['status'] as String?),
        );
      case 'typing':
        return TypingEvent(
          conversationId: json['conversationId']! as String,
          senderId: json['senderId']! as String,
          isTyping: (json['isTyping'] as bool?) ?? true,
        );
      case 'error':
        return ServerErrorEvent(
          code: (json['code'] as String?) ?? 'unknown',
          message: (json['message'] as String?) ?? '',
        );
      default:
        return UnknownEvent(rawType: wire ?? '');
    }
  }

  static ChatMessageStatus _statusFromAck(String? raw) {
    switch (raw) {
      case 'delivered':
        return ChatMessageStatus.delivered;
      case 'read':
        return ChatMessageStatus.read;
      case 'failed':
        return ChatMessageStatus.failed;
      case 'sent':
      default:
        return ChatMessageStatus.sent;
    }
  }
}

class MessageReceivedEvent extends ChatEvent {
  const MessageReceivedEvent({required this.message});
  final ChatMessage message;

  @override
  ChatEventType get type => ChatEventType.messageReceived;

  @override
  List<Object?> get props => [message];
}

class MessageAckEvent extends ChatEvent {
  const MessageAckEvent({
    required this.clientId,
    required this.status,
    this.serverId,
  });

  final String clientId;
  final String? serverId;
  final ChatMessageStatus status;

  @override
  ChatEventType get type => ChatEventType.ack;

  @override
  List<Object?> get props => [clientId, serverId, status];
}

class TypingEvent extends ChatEvent {
  const TypingEvent({
    required this.conversationId,
    required this.senderId,
    required this.isTyping,
  });

  final String conversationId;
  final String senderId;
  final bool isTyping;

  @override
  ChatEventType get type => ChatEventType.typing;

  @override
  List<Object?> get props => [conversationId, senderId, isTyping];
}

class ServerErrorEvent extends ChatEvent {
  const ServerErrorEvent({required this.code, required this.message});
  final String code;
  final String message;

  @override
  ChatEventType get type => ChatEventType.error;

  @override
  List<Object?> get props => [code, message];
}

class UnknownEvent extends ChatEvent {
  const UnknownEvent({required this.rawType});
  final String rawType;

  @override
  ChatEventType get type => ChatEventType.unknown;

  @override
  List<Object?> get props => [rawType];
}
