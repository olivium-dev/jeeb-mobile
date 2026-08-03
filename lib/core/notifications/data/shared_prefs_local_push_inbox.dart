import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_push_inbox.dart';

/// write race — mirrors the persistence class of the other on-device stores
class SharedPrefsLocalPushInbox implements LocalPushInbox {
  SharedPrefsLocalPushInbox({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'jeeb.push_inbox.';

  static const int _maxRows = 50;

  static String _keyFor(String id) => '$_keyPrefix$id';

  Iterable<String> _rowKeys() =>
      _prefs.getKeys().where((k) => k.startsWith(_keyPrefix));

  @override
  Future<void> append(LocalPushRecord record) async {
    if (record.id.isEmpty) return;
    await _prefs.reload();
    await _prefs.setString(_keyFor(record.id), record.encode());
    await _evictOverflow();
  }

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
