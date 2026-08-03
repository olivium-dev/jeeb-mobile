// QA-PRE for JEB-1423 (T-MOB-FIX-005). Binds the wire-shape `ChatMessage`

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/features/chat/data/shared_prefs_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';

ChatMessage _msg(String id) => ChatMessage(
      clientId: id,
      conversationId: 'conv',
      senderId: 'u-1',
      body: 'hi $id',
      createdAt: DateTime.utc(2026, 5, 17),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SharedPrefsChatOutbox', () {
    test('starts empty', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      expect(await outbox.load(), isEmpty);
    });

    test('enqueue appends and persists FIFO order', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      await outbox.enqueue(_msg('b'));
      await outbox.enqueue(_msg('c'));
      final ids = (await outbox.load()).map((m) => m.clientId).toList();
      expect(ids, ['a', 'b', 'c']);

      // Survives a fresh load by reading from the persisted store.
      final reload = SharedPrefsChatOutbox(prefs: prefs);
      final reloadIds = (await reload.load()).map((m) => m.clientId).toList();
      expect(reloadIds, ['a', 'b', 'c']);
    });

    test('remove drops the given clientId', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      await outbox.enqueue(_msg('b'));
      await outbox.remove('a');
      final ids = (await outbox.load()).map((m) => m.clientId).toList();
      expect(ids, ['b']);
    });

    test('update mutates in place; no-op when missing', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      final updated = _msg('a').copyWith(
        status: ChatMessageStatus.failed,
        attempts: 4,
      );
      await outbox.update(updated);
      final loaded = await outbox.load();
      expect(loaded.first.status, ChatMessageStatus.failed);
      expect(loaded.first.attempts, 4);

      await outbox.update(_msg('missing'));
      expect((await outbox.load()).length, 1);
    });

    test('corrupt payload resets the store', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat.outbox.v1': '{not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      expect(await outbox.load(), isEmpty);
      expect(prefs.getString('chat.outbox.v1'), isNull);
    });

    test('markFailed default impl flips status without removing entry',
        () async {
      // Sanity-check that the default `markFailed` (declared on the abstract
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      await outbox.enqueue(_msg('b'));
      await outbox.markFailed('a');
      final loaded = await outbox.load();
      expect(loaded.length, 2);
      expect(loaded.firstWhere((m) => m.clientId == 'a').status,
          ChatMessageStatus.failed);
      expect(loaded.firstWhere((m) => m.clientId == 'b').status,
          ChatMessageStatus.pending);
    });

    test('survives reload after markFailed (status persists to disk)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      await outbox.markFailed('a');

      final reload = SharedPrefsChatOutbox(prefs: prefs);
      final loaded = await reload.load();
      expect(loaded.single.status, ChatMessageStatus.failed);
    });
  });
}
