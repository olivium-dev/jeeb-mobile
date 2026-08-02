import 'dart:convert';

import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import 'chat_message_codec.dart';

class FirestoreChatMessageMapper {
  FirestoreChatMessageMapper({
    required this.currentUserId,
    ChatMessageCodec? codec,
  }) : _codec = codec ?? ChatMessageCodec(currentUserId);

  final String currentUserId;

  final ChatMessageCodec _codec;

  ChatEvent? map(RealtimeDocChange change) {
    final row = toWireRow(change);
    if (row == null) return null;
    if (!ChatMessageCodec.isValidRow(row)) return null;
    try {
      return IncomingMessage(_codec.parse(row));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? toWireRow(RealtimeDocChange change) {
    final data = change.data;

    if (data['IsDeleted'] == true) return null;
    if (data['DeletedAt'] != null) return null;
    if (data['IsActive'] == false) return null;

    final id = _stringOf(data['Guid']) ?? change.id;
    if (id.isEmpty) return null;

    final row = <String, dynamic>{
      'message_id': id,
      'author_id': _stringOf(data['AuthorId']) ?? '',
      'kind': _stringOf(data['Kind']) ?? '',
      'subtype': _stringOf(data['Subtype']),
    };

    final createdAt = _isoOf(data[kChatMessageCreatedAtField]);
    if (createdAt != null) row['created_at'] = createdAt;

    final body = _stringOf(data['Body']);
    final payload = _payloadOf(data['Payload']);
    if (body != null && body.isNotEmpty) {
      row['body'] = body;
    } else if (payload != null) {
      row['payload'] = payload;
    } else if (body != null) {
      row['body'] = body;
    }
    return row;
  }

  static String? _stringOf(Object? raw) => raw is String ? raw : null;

  static Object? _payloadOf(Object? raw) {
    if (raw is Map) return raw.cast<String, Object?>();
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {
    }
    return raw;
  }

  static String? _isoOf(Object? raw) {
    if (raw is DateTime) return raw.toUtc().toIso8601String();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null || parsed.year <= 1) return null;
      return parsed.toUtc().toIso8601String();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true)
          .toIso8601String();
    }
    return null;
  }
}
