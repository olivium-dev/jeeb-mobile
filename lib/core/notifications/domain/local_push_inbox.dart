// PURE Dart. No Flutter / Firebase / SharedPreferences imports here
// (40_GUARDRAILS_ARCH §1 layer rules) — this is the domain contract; the
// SharedPreferences impl lives in `data/shared_prefs_local_push_inbox.dart`.

import 'dart:convert';

/// The wire `type` value the gateway stamps on a jeeber new-request broadcast
/// (`NewRequestPushNotifier`). Shared by the push writers (foreground handler +
/// background isolate) and the badge derivation so the "is this a new_request"
/// test lives in exactly one place.
const String kNewRequestPushType = 'new_request';

/// A durable, on-device record of a push that the SERVER notifications inbox
/// (`GET /v1/notifications`) does NOT source — today only the jeeber
/// `new_request` broadcast (G3).
///
/// Why this exists (G3 root cause, run-24 CHECK D): a `new_request` push that
/// arrives while the app is backgrounded/terminated is handled ONLY by the FCM
/// background isolate (`firebaseMessagingBackgroundHandler`). That isolate has
/// no access to the in-memory [BadgeCountCubit] or the inbox list, and the
/// server inbox has no `new_request` row to pull — so a dismissed push left NO
/// trail (empty inbox, no badge) even though the cubit + inbox-row code were
/// correct and unit-tested. Persisting the push here, readable from the main
/// isolate on resume, is the bridge that makes a dismissed push findable.
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

  /// FCM `messageId` (or a synthesized fallback) — the SharedPreferences row key
  /// and the inbox-row id. Dedups a message delivered to both isolates.
  final String id;

  /// The gateway wire `type` (e.g. [kNewRequestPushType]). Stored raw so this
  /// core store never depends on the features-layer `NotificationKind`.
  final String type;

  final String title;
  final String body;

  /// ISO-8601 UTC instant the push was sent/received. Drives newest-first order
  /// and the row's relative timestamp.
  final String ts;

  /// Deep-link target id (the `requestId` for a new_request) — rides the inbox
  /// row's `ref` chain so a tap routes via `deepLinkForMessage`.
  final String? ref;

  /// Inbox unread flag — flipped by a per-row tap / entering the inbox.
  final bool read;

  /// Feed-tab flag — flipped once the jeeber has viewed the request feed, so the
  /// Dashboard-tab badge ([BadgeCounts.newRequests]) stops counting it (and does
  /// NOT resurrect on the next resume).
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

/// On-device store for pushes the server inbox does not source (G3).
///
/// Writable from BOTH the FCM background isolate (which constructs the impl
/// directly — GetIt is not configured there) and the main isolate. Reads
/// re-sync from disk first so the main isolate sees a background-isolate write.
abstract class LocalPushInbox {
  /// Persist one push. Dedups by [LocalPushRecord.id] (a message delivered to
  /// both the foreground and background paths yields one row) and caps the
  /// store so a noisy server can't grow it without bound.
  Future<void> append(LocalPushRecord record);

  /// Every stored push, newest-first. Re-reads from disk so a write made by the
  /// background isolate is visible.
  Future<List<LocalPushRecord>> readAll();

  /// Mark one row read. Returns `true` when a local row matched [id] (so the
  /// caller can skip the server PATCH for a local-only row).
  Future<bool> markRead(String id);

  /// Entering the inbox surfaces every push — mark them all read.
  Future<void> markAllRead();

  /// Viewing the request feed — the open requests are on screen, so every
  /// new_request row is now "seen" and must not badge the feed tab again.
  Future<void> markAllNewRequestsSeenInFeed();
}
