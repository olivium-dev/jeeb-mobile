import 'dart:convert';

import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import 'chat_message_codec.dart';

/// Turns a chat-service Firestore message DOCUMENT into the flat wire row
/// [ChatMessageCodec] already knows how to decode.
///
/// # Why a normaliser instead of a second decoder
///
/// The document and the HTTP projection are the same message in two different
/// spellings. Firestore holds the C# POCO as written by
/// `chat-service/ChatService.Persistence/FirestoreConversationStore.cs:109`
/// (`SetAsync(message)` with the native `[FirestoreData]` mapper), so the field
/// names ARE the property names — PascalCase:
///
/// | document (`ConversationMessage` + `BaseModel`) | wire row (`JeebMessageResponse`) |
/// |---|---|
/// | `Guid` (and the document id — the store writes `.Document(message.Guid)`) | `message_id` |
/// | `AuthorId`   | `author_id`   |
/// | `Kind`       | `kind`        |
/// | `Subtype`    | `subtype`     |
/// | `Body`       | `body`        |
/// | `Payload` (a JSON **string**) | `payload` (an object) |
/// | `CreatedAt` (a Firestore `Timestamp`) | `created_at` (ISO-8601) |
///
/// Normalising here and reusing the codec means the nine-branch kind switch, the
/// `0001-01-01` husk rule, the string-vs-map `body` rule and the `photo`
/// placeholder rule are shared by both transports rather than reimplemented for
/// this one. A second decoder is how a message renders over HTTP and vanishes
/// over the stream.
///
/// # Payload: string-or-map
///
/// `ConversationMessage.Payload` is `public string` — a structured payload is
/// stored as JSON TEXT, not as a nested map. The HTTP hop parses it back into an
/// object before the client sees it; the document does not. So this mapper
/// decodes it, and falls back to treating it as opaque text when it does not
/// parse to a map.
///
/// This is the same branch Rahmah has to write for the same reason —
/// `rahmah-fe/lib/features/chat/presentation/screens/chat_screen.dart:307-319`
/// (`if (payload is String) jsonDecode(payload) else if (payload is Map) ...`).
class FirestoreChatMessageMapper {
  FirestoreChatMessageMapper({
    required this.currentUserId,
    ChatMessageCodec? codec,
  }) : _codec = codec ?? ChatMessageCodec(currentUserId);

  /// Jeeb user id of the local viewer — compared against `AuthorId` to derive
  /// own-vs-counterpart, exactly as the HTTP path does.
  final String currentUserId;

  final ChatMessageCodec _codec;

  /// Decodes [change] into an [IncomingMessage], or null when the document
  /// cannot be rendered (soft-deleted, malformed, or an unsupported kind).
  ///
  /// Null is a SKIP, never a throw: one bad document must not tear down the
  /// listener for the whole thread.
  ChatEvent? map(RealtimeDocChange change) {
    final row = toWireRow(change);
    if (row == null) return null;
    if (!ChatMessageCodec.isValidRow(row)) return null;
    try {
      // No `fallbackSentAt`: a document that arrives with no usable `CreatedAt`
      // is a LIVE frame, and the codec stamps it at arrival — which for a frame
      // that just crossed the wire is its send time to within transport latency.
      // Handing it a synthetic 1970 anchor here (the HTTP path's device, where
      // rows arrive in a known server ARRAY order) would instead bury it at the
      // top of the thread: a stream has no array to take an order from.
      return IncomingMessage(_codec.parse(row));
    } catch (_) {
      return null;
    }
  }

  /// The document, flattened into the codec's wire shape. Null when the document
  /// is soft-deleted.
  ///
  /// Visible for testing so the normalisation can be asserted field-by-field
  /// without a Firebase app.
  Map<String, dynamic>? toWireRow(RealtimeDocChange change) {
    final data = change.data;

    // Soft delete. `BaseModel` carries `IsDeleted`/`DeletedAt`/`IsActive`; the
    // Jeeb message path is append-only today and never sets them, but a
    // subscriber that ignored them would resurrect a message the REST read
    // suppresses the moment anything starts setting them.
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
    // `body` wins for text; `payload` carries everything structured. The codec
    // reads `body ?? payload`, so only ever hand it the one that applies —
    // otherwise an empty `Body` on a structured message would shadow the
    // payload and render an empty bubble.
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

  /// `Payload` is JSON TEXT in the document. Decode it to the map the codec
  /// expects; leave anything that does not parse to a map as opaque text (the
  /// codec then renders it as the bubble's text rather than dropping the row).
  static Object? _payloadOf(Object? raw) {
    if (raw is Map) return raw.cast<String, Object?>();
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, Object?>();
    } catch (_) {
      // Not JSON — fall through and carry it as text.
    }
    return raw;
  }

  /// `CreatedAt` as an ISO-8601 string.
  ///
  /// The Firestore adapter converts the SDK's `Timestamp` to a [DateTime] before
  /// this is reached (that is the whole reason this file imports no
  /// `cloud_firestore`), but the other shapes are tolerated because a document
  /// written by a different client, or replayed from a fixture, can carry them.
  static String? _isoOf(Object? raw) {
    if (raw is DateTime) return raw.toUtc().toIso8601String();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      // `0001-01-01` — the .NET `default(DateTime)` husk — is not a send time.
      // Dropping it here means the codec's `hasServerTimestamp: false` rule
      // fires, exactly as it does on the HTTP path.
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
