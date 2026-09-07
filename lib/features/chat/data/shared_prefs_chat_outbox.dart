import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/chat_message.dart';
import '../domain/chat_outbox.dart';

class SharedPrefsChatOutbox extends ChatOutbox
    implements AccountScopedChatOutbox {
  SharedPrefsChatOutbox({
    required SharedPreferences prefs,
    this.storageKey = _defaultKey,
  }) : _prefs = prefs;

  static const _defaultKey = 'chat.outbox.v1';

  final SharedPreferences _prefs;
  final String storageKey;

  List<ChatMessage>? _cache;
  bool _reloadAfterFailure = false;
  final Map<String, ChatOutbox> _accounts = {};

  @override
  ChatOutbox forAccount(String userId) {
    if (userId.isEmpty) throw ArgumentError.value(userId, 'userId');
    return _accounts.putIfAbsent(
      userId,
      () => _AccountOutbox(
        userId: userId,
        legacy: this,
        scoped: SharedPrefsChatOutbox(
          prefs: _prefs,
          storageKey:
              '$storageKey.account.${base64Url.encode(utf8.encode(userId))}',
        ),
      ),
    );
  }

  @override
  Future<List<ChatMessage>> load() async {
    if (_reloadAfterFailure) {
      await _prefs.reload();
      _reloadAfterFailure = false;
    }
    final cached = _cache;
    if (cached != null) return List.unmodifiable(cached);
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = <ChatMessage>[];
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List;
      final hydrated = decoded
          .cast<Map>()
          .map((m) => ChatMessage.fromJson(m.cast<String, Object?>()))
          .toList();
      _cache = hydrated;
      return List.unmodifiable(hydrated);
    } catch (_) {
      _cache = <ChatMessage>[];
      await _prefs.remove(storageKey);
      return const [];
    }
  }

  @override
  Future<void> enqueue(ChatMessage message) async {
    final list = await _mutableCache();
    list.add(message);
    await _flush(list);
  }

  @override
  Future<void> remove(String clientId) async {
    final list = await _mutableCache();
    list.removeWhere((m) => m.clientId == clientId);
    await _flush(list);
  }

  Future<void> _removeOwned(ChatMessage row) async {
    final list = await _mutableCache();
    list.removeWhere(
      (m) => m.clientId == row.clientId && m.senderId == row.senderId,
    );
    await _flush(list);
  }

  @override
  Future<void> update(ChatMessage message) async {
    final list = await _mutableCache();
    final idx = list.indexWhere((m) => m.clientId == message.clientId);
    if (idx == -1) return;
    list[idx] = message;
    await _flush(list);
  }

  Future<List<ChatMessage>> _mutableCache() async {
    await load();
    return _cache!;
  }

  Future<void> _flush(List<ChatMessage> list) async {
    final encoded = jsonEncode(list.map((m) => m.toJson()).toList());
    try {
      if (!await _prefs.setString(storageKey, encoded)) {
        throw StateError('Chat outbox was not persisted');
      }
    } catch (_) {
      _cache = null;
      _reloadAfterFailure = true;
      rethrow;
    }
  }
}

class _AccountOutbox extends ChatOutbox {
  _AccountOutbox({
    required this.userId,
    required this.legacy,
    required this.scoped,
  });

  final String userId;
  final SharedPrefsChatOutbox legacy;
  final ChatOutbox scoped;
  Future<void>? _migration;

  Future<void> _migrate() async {
    final existing = (await scoped.load()).map((row) => row.clientId).toSet();
    for (final row in await legacy.load()) {
      if (row.senderId != userId) continue;
      if (existing.add(row.clientId)) await scoped.enqueue(row);
      await legacy._removeOwned(row);
    }
  }

  @override
  Future<List<ChatMessage>> load() async {
    try {
      await (_migration ??= _migrate());
    } catch (_) {
      _migration = null;
      rethrow;
    }
    return (await scoped.load())
        .where((row) => row.senderId == userId)
        .toList(growable: false);
  }

  @override
  Future<void> enqueue(ChatMessage message) async {
    if (message.senderId != userId) return;
    await load();
    await scoped.enqueue(message);
  }

  @override
  Future<void> update(ChatMessage message) async {
    if (message.senderId != userId) return;
    await load();
    await scoped.update(message);
  }

  @override
  Future<void> remove(String clientId) async {
    if (!(await load()).any((row) => row.clientId == clientId)) return;
    await scoped.remove(clientId);
  }
}
