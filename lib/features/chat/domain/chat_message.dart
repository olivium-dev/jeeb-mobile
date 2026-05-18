import 'package:equatable/equatable.dart';

/// Lifecycle status of an outbound chat message on the wire.
///
/// LEAD pin (JEB-1423 comment #14900) — the canonical set is five values in
/// this order. The historical AC list cited `{queued, sending, ...}`; that
/// wording is superseded — `pending` is the post-enqueue / pre-ack state.
enum ChatMessageStatus { pending, sent, delivered, read, failed }

/// Canonical wire-shape chat message exchanged with the chat-service.
///
/// Eight fields per the LEAD pin: `clientId`, `serverId`, `conversationId`,
/// `senderId`, `body`, `createdAt`, `attempts`, `status`. The codec is
/// hand-written (Option A — no build_runner) so the JSON keys and the enum
/// lowercase names are the contract.
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

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      clientId: json['clientId']! as String,
      serverId: json['serverId'] as String?,
      conversationId: json['conversationId']! as String,
      senderId: json['senderId']! as String,
      body: json['body']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      attempts: (json['attempts'] as int?) ?? 0,
      status: _statusFromName(json['status'] as String?),
    );
  }

  /// Locally-generated id assigned when the cubit enqueues the message.
  /// Pairs with [serverId] once the server has accepted the send.
  final String clientId;

  /// Server-assigned id, present once the message has been acked. Null while
  /// the message is still pending or has failed.
  final String? serverId;

  final String conversationId;
  final String senderId;
  final String body;

  /// Wall-clock at enqueue time. Always serialized as UTC ISO-8601.
  final DateTime createdAt;

  /// Number of transport attempts made so far. Bumped by the flush path;
  /// reset to 0 by the retry path.
  final int attempts;

  final ChatMessageStatus status;

  Map<String, Object?> toJson() => <String, Object?>{
        'clientId': clientId,
        'serverId': serverId,
        'conversationId': conversationId,
        'senderId': senderId,
        'body': body,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'status': status.name,
      };

  ChatMessage copyWith({
    String? clientId,
    Object? serverId = _sentinel,
    String? conversationId,
    String? senderId,
    String? body,
    DateTime? createdAt,
    int? attempts,
    ChatMessageStatus? status,
  }) {
    return ChatMessage(
      clientId: clientId ?? this.clientId,
      serverId: identical(serverId, _sentinel)
          ? this.serverId
          : serverId as String?,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
    );
  }

  static ChatMessageStatus _statusFromName(String? raw) {
    if (raw == null) return ChatMessageStatus.pending;
    for (final s in ChatMessageStatus.values) {
      if (s.name == raw) return s;
    }
    return ChatMessageStatus.pending;
  }

  @override
  List<Object?> get props => [
        clientId,
        serverId,
        conversationId,
        senderId,
        body,
        createdAt,
        attempts,
        status,
      ];
}

const Object _sentinel = Object();
