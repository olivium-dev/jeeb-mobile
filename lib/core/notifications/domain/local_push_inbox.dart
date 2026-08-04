import 'dart:convert';

const String kNewRequestPushType = 'new_request';

class LocalPushRecord {
  const LocalPushRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.ts,
    this.ref,
    this.read = false,
    this.seenInFeed = false,
  });

  final String id;

  final String type;

  final String title;
  final String body;

  final String ts;

  final String? ref;

  final bool read;

  final bool seenInFeed;

  LocalPushRecord copyWith({bool? read, bool? seenInFeed}) {
    return LocalPushRecord(
      id: id,
      type: type,
      title: title,
      body: body,
      ts: ts,
      ref: ref,
      read: read ?? this.read,
      seenInFeed: seenInFeed ?? this.seenInFeed,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'ts': ts,
        'ref': ref,
        'read': read,
        'seenInFeed': seenInFeed,
      };

  static LocalPushRecord? tryDecode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final id = json['id'];
      final type = json['type'];
      if (id is! String || id.isEmpty || type is! String) return null;
      return LocalPushRecord(
        id: id,
        type: type,
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        ts: (json['ts'] as String?) ?? '',
        ref: json['ref'] as String?,
        read: json['read'] == true,
        seenInFeed: json['seenInFeed'] == true,
      );
    } catch (_) {
      // A corrupt/partial row must never crash a read — drop it silently.
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

abstract class LocalPushInbox {
  Future<void> append(LocalPushRecord record);

  Future<List<LocalPushRecord>> readAll();

  Future<bool> markRead(String id);

  Future<void> markAllRead();

  /// new_request row is now "seen" and must not badge the feed tab again.
  Future<void> markAllNewRequestsSeenInFeed();
}
