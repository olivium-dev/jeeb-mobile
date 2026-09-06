import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_push_inbox.dart';

/// write race — mirrors the persistence class of the other on-device stores
class SharedPrefsLocalPushInbox implements LocalPushInbox {
  SharedPrefsLocalPushInbox({
    required SharedPreferences prefs,
    String? ownerId,
  }) : _prefs = prefs,
       _ownerId = ownerId;

  final SharedPreferences _prefs;

  /// null = resolve the owner from [ownerPrefKey] on every access, so the
  /// DI-built instance follows the signed-in account without being rebuilt.
  final String? _ownerId;

  static const String keyPrefix = 'jeeb.push_inbox.';

  /// Deliberately NOT under [keyPrefix]: a row sweep must not eat the stamp.
  static const String ownerPrefKey = 'jeeb.push_inbox_owner';

  static const String _anonOwner = '_';

  static const int _maxRows = 50;

  /// F7: rows are keyed `jeeb.push_inbox.<owner>.<id>`; the owner segment is
  /// squashed to key-safe characters so the first '.' always ends it.
  static String ownerSegment(String? ownerId) {
    final trimmed = ownerId?.trim() ?? '';
    if (trimmed.isEmpty) return _anonOwner;
    return trimmed.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
  }

  static String? _ownerOfKey(String key) {
    if (!key.startsWith(keyPrefix)) return null;
    final rest = key.substring(keyPrefix.length);
    final dot = rest.indexOf('.');
    // No owner segment = a legacy unscoped row: owned by nobody, never read.
    if (dot <= 0 || dot == rest.length - 1) return null;
    return rest.substring(0, dot);
  }

  String get _owner =>
      ownerSegment(_ownerId ?? _prefs.getString(ownerPrefKey));

  String _keyFor(String id) => '$keyPrefix$_owner.$id';

  Iterable<String> _rowKeys() {
    final owner = _owner;
    return _prefs
        .getKeys()
        .where((k) => _ownerOfKey(k) == owner)
        .toList(growable: false);
  }

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
    for (final key in _rowKeys()) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      final record = LocalPushRecord.tryDecode(raw);
      if (record != null) out.add(record);
    }
    return out;
  }

  /// F7: another account's rows (or pre-stamp legacy ones) are not this user's
  /// inbox — drop them so they can never be merged into it again.
  Future<void> _pruneForeignRows() async {
    final owner = _owner;
    if (owner == _anonOwner) return;
    final foreign = _prefs
        .getKeys()
        .where((k) => k.startsWith(keyPrefix) && _ownerOfKey(k) != owner)
        .toList(growable: false);
    for (final key in foreign) {
      await _prefs.remove(key);
    }
  }

  @override
  Future<List<LocalPushRecord>> readAll() async {
    await _prefs.reload();
    await _pruneForeignRows();
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
    for (final key in _rowKeys()) {
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

  /// Logout sweep: every account's rows plus the owner stamp itself.
  static Future<void> clearAll(SharedPreferences prefs) async {
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(keyPrefix) || k == ownerPrefKey)
        .toList(growable: false);
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Mirrors the signed-in user id for the FCM background isolate, which has no
  /// keystore access and can only read prefs.
  static Future<void> stampOwner(
    SharedPreferences prefs,
    String? ownerId,
  ) async {
    final value = ownerId?.trim() ?? '';
    if (value.isEmpty) {
      await prefs.remove(ownerPrefKey);
      return;
    }
    if (prefs.getString(ownerPrefKey) == value) return;
    await prefs.setString(ownerPrefKey, value);
  }
}
