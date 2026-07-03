import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_push_inbox.dart';

/// SharedPreferences-backed [LocalPushInbox].
///
/// One row per push: `jeeb.push_inbox.<messageId>` → the JSON-encoded
/// [LocalPushRecord]. Per-key (not a single JSON blob) so a background-isolate
/// append and a main-isolate append never clobber each other in a read-modify-
/// write race — mirrors the persistence class of the other on-device stores
/// (`SharedPrefsHandoverCodeStore`, `SharedPrefsPinRepository`): plain prefs,
/// bounded, cleared with an uninstall.
///
/// CROSS-ISOLATE: the FCM background handler runs in a SEPARATE isolate with a
/// SEPARATE SharedPreferences cache but the SAME on-disk file. Every read here
/// calls [SharedPreferences.reload] first so the main isolate observes a write
/// the background isolate made while the app was backgrounded/terminated.
class SharedPrefsLocalPushInbox implements LocalPushInbox {
  SharedPrefsLocalPushInbox({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'jeeb.push_inbox.';

  /// Bound the store so a runaway server can't fill the device. Newest-first;
  /// the oldest rows are evicted on append past the cap.
  static const int _maxRows = 50;

  static String _keyFor(String id) => '$_keyPrefix$id';

  Iterable<String> _rowKeys() =>
      _prefs.getKeys().where((k) => k.startsWith(_keyPrefix));

  @override
  Future<void> append(LocalPushRecord record) async {
    if (record.id.isEmpty) return;
    await _prefs.reload();
    // Dedup: a message delivered to both isolates (or re-delivered) writes the
    // same key, so it collapses to one row.
    await _prefs.setString(_keyFor(record.id), record.encode());
    await _evictOverflow();
  }

  /// Keep at most [_maxRows], dropping the oldest by timestamp.
  Future<void> _evictOverflow() async {
    final records = await _readAllUnsorted();
    if (records.length <= _maxRows) return;
    records.sort((a, b) => _compareTs(a.ts, b.ts)); // oldest first
    final overflow = records.length - _maxRows;
    for (var i = 0; i < overflow; i++) {
      await _prefs.remove(_keyFor(records[i].id));
    }
  }

  Future<List<LocalPushRecord>> _readAllUnsorted() async {
    final out = <LocalPushRecord>[];
    for (final key in _rowKeys().toList(growable: false)) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      final record = LocalPushRecord.tryDecode(raw);
      if (record != null) out.add(record);
    }
    return out;
  }

  @override
  Future<List<LocalPushRecord>> readAll() async {
    await _prefs.reload();
    final records = await _readAllUnsorted();
    records.sort((a, b) => _compareTs(b.ts, a.ts)); // newest first
    return List<LocalPushRecord>.unmodifiable(records);
  }

  /// Newest-first when used as `_compareTs(b, a)`. A row with an unparseable /
  /// empty timestamp sorts last (never jumps to the top).
  static int _compareTs(String a, String b) {
    final ta = DateTime.tryParse(a);
    final tb = DateTime.tryParse(b);
    if (ta == null && tb == null) return 0;
    if (ta == null) return -1;
    if (tb == null) return 1;
    return ta.compareTo(tb);
  }

  @override
  Future<bool> markRead(String id) async {
    if (id.isEmpty) return false;
    await _prefs.reload();
    final raw = _prefs.getString(_keyFor(id));
    if (raw == null) return false;
    final record = LocalPushRecord.tryDecode(raw);
    if (record == null) return false;
    if (!record.read) {
      await _prefs.setString(_keyFor(id), record.copyWith(read: true).encode());
    }
    return true;
  }

  @override
  Future<void> markAllRead() => _mutateAll((r) => r.copyWith(read: true));

  @override
  Future<void> markAllNewRequestsSeenInFeed() => _mutateAll(
        (r) => r.type == kNewRequestPushType
            ? r.copyWith(seenInFeed: true)
            : r,
      );

  Future<void> _mutateAll(LocalPushRecord Function(LocalPushRecord) update) async {
    await _prefs.reload();
    for (final key in _rowKeys().toList(growable: false)) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      final record = LocalPushRecord.tryDecode(raw);
      if (record == null) continue;
      final updated = update(record);
      if (!identical(updated, record)) {
        await _prefs.setString(key, updated.encode());
      }
    }
  }
}
