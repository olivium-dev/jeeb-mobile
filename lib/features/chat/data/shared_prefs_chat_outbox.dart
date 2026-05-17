import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/chat_message.dart';
import '../domain/chat_outbox.dart';

/// [ChatOutbox] backed by a single SharedPreferences key holding a JSON
/// array. Good enough for the MVP volume target (per-user low double-digit
/// pending messages); migrate to sqflite if we ever need to support
/// thousands of messages.
class SharedPrefsChatOutbox extends ChatOutbox {
  SharedPrefsChatOutbox({
    required SharedPreferences prefs,
    this.storageKey = _defaultKey,
  }) : _prefs = prefs;

  static const _defaultKey = 'chat.outbox.v1';

  final SharedPreferences _prefs;
  final String storageKey;

  // In-memory mirror so we don't re-decode JSON on every read. Kept in sync
  // by every write path below.
  List<ChatMessage>? _cache;

  @override
  Future<List<ChatMessage>> load() async {
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
      // Corrupt store — start fresh rather than crash. The data we'd be
      // protecting is best-effort offline drafts; treating it as ephemeral
      // is the right failure mode.
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
    await _prefs.setString(storageKey, encoded);
  }
}
