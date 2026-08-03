import 'package:equatable/equatable.dart';

enum ChatMessageStatus { pending, sent, delivered, read, failed }

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

  final String clientId;

  final String? serverId;

  final String conversationId;
  final String senderId;
  final String body;

  /// Wall-clock at enqueue time. Always serialized as UTC ISO-8601.
  final DateTime createdAt;

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
