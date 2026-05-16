import 'package:equatable/equatable.dart';

/// Per-message delivery state owned by the client.
///
/// `pending` — sitting in the offline outbox, not yet acked by the gateway.
/// `sent` — the gateway accepted the envelope (server-issued ack).
/// `delivered` — the recipient's device acknowledged receipt.
/// `read` — the recipient opened the conversation.
/// `failed` — gateway rejected, or the outbox gave up after max retries.
enum ChatMessageStatus { pending, sent, delivered, read, failed }

ChatMessageStatus _statusFromWire(String? wire) {
  switch (wire) {
    case 'sent':
      return ChatMessageStatus.sent;
    case 'delivered':
      return ChatMessageStatus.delivered;
    case 'read':
      return ChatMessageStatus.read;
    case 'failed':
      return ChatMessageStatus.failed;
    case 'pending':
    default:
      return ChatMessageStatus.pending;
  }
}

String _statusToWire(ChatMessageStatus s) => s.name;

/// A single chat message. The `clientId` is a UUID-like opaque token minted
/// by the device so the gateway can de-duplicate retries; once the server
/// assigns a permanent id the cubit folds it into [serverId].
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.clientId,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.serverId,
    this.status = ChatMessageStatus.pending,
    this.attempts = 0,
  });

  /// Client-side id used to correlate retries and acks. Always non-null,
  /// even after the server assigns [serverId].
  final String clientId;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  /// Server-assigned id. Null until the gateway acks the send.
  final String? serverId;

  final ChatMessageStatus status;

  /// Send attempts so far. The outbox uses this to give up after a ceiling
  /// rather than spinning forever on a poison-pill payload.
  final int attempts;

  ChatMessage copyWith({
    String? serverId,
    ChatMessageStatus? status,
    int? attempts,
  }) {
    return ChatMessage(
      clientId: clientId,
      conversationId: conversationId,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
      serverId: serverId ?? this.serverId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, Object?> toJson() => {
        'clientId': clientId,
        'conversationId': conversationId,
        'senderId': senderId,
        'body': body,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'serverId': serverId,
        'status': _statusToWire(status),
        'attempts': attempts,
      };

  static ChatMessage fromJson(Map<String, Object?> json) {
    return ChatMessage(
      clientId: json['clientId']! as String,
      conversationId: json['conversationId']! as String,
      senderId: json['senderId']! as String,
      body: json['body']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      serverId: json['serverId'] as String?,
      status: _statusFromWire(json['status'] as String?),
      attempts: (json['attempts'] as int?) ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [clientId, conversationId, senderId, body, createdAt, serverId, status, attempts];
}
