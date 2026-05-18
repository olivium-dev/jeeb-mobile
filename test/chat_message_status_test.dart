// QA-PRE for JEB-1423 (T-MOB-FIX-005). Pins the ChatMessageStatus state
// machine and the ChatOutbox.markFailed default impl per the LEAD pin
// (comment #14900).
//
// LEAD-pin reconciliation: the parent issue's AC list quoted the status enum
// as `{queued, sending, sent, delivered, read, failed}`. The LEAD pin
// supersedes that with `{pending, sent, delivered, read, failed}` — there is
// no `queued` or `sending` value. The pin also re-frames the state machine
// in terms of `pending` as the "outbound-not-yet-acked" state. These tests
// follow the LEAD pin.
//
// Happy path        : pending → sent → delivered → read    (server acks)
// Dead-letter path  : pending → failed                       (server error)
// Retry semantics   : failed → pending (and attempts → 0)   (user tap)
//
// `markFailed` is the ChatOutbox default impl that walks the persisted queue
// and flips the matching entry's status to `failed` WITHOUT removing it —
// the entry must stay so the UI can render a retry-able badge.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/data/shared_prefs_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';

ChatMessage _msg(String id, {
  ChatMessageStatus status = ChatMessageStatus.pending,
  int attempts = 0,
  String? serverId,
}) =>
    ChatMessage(
      clientId: id,
      conversationId: 'conv',
      senderId: 'u-1',
      body: 'body-$id',
      createdAt: DateTime.utc(2026, 5, 17),
      status: status,
      attempts: attempts,
      serverId: serverId,
    );

void main() {
  group('ChatMessageStatus enum surface', () {
    test('contains exactly the LEAD-pinned 5 values in the pinned order', () {
      // Order matters per LEAD pin Decision 3 — pinned: pending, sent,
      // delivered, read, failed. (The historical "queued" / "sending"
      // names from the AC list are explicitly out per the pin.)
      expect(ChatMessageStatus.values.map((s) => s.name).toList(), <String>[
        'pending',
        'sent',
        'delivered',
        'read',
        'failed',
      ]);
    });
  });

  group('ChatMessage status transitions via copyWith', () {
    test('happy path: pending → sent → delivered → read', () {
      var msg = _msg('c-1');
      expect(msg.status, ChatMessageStatus.pending);

      msg = msg.copyWith(status: ChatMessageStatus.sent, serverId: 's-1');
      expect(msg.status, ChatMessageStatus.sent);
      expect(msg.serverId, 's-1');
      expect(msg.clientId, 'c-1');

      msg = msg.copyWith(status: ChatMessageStatus.delivered);
      expect(msg.status, ChatMessageStatus.delivered);
      expect(msg.serverId, 's-1');

      msg = msg.copyWith(status: ChatMessageStatus.read);
      expect(msg.status, ChatMessageStatus.read);
      expect(msg.serverId, 's-1');
    });

    test('dead-letter: pending → failed', () {
      var msg = _msg('c-2');
      msg = msg.copyWith(status: ChatMessageStatus.failed);
      expect(msg.status, ChatMessageStatus.failed);
      // attempts is independently tracked — flipping to failed must not zero
      // it on its own. The cubit's retry() is the only path that resets.
      expect(msg.attempts, 0);
    });

    test('retry semantics: failed → pending with attempts reset to 0', () {
      // Build a message that already cycled through one failed send.
      var msg = _msg('c-3', status: ChatMessageStatus.failed, attempts: 3);
      expect(msg.status, ChatMessageStatus.failed);
      expect(msg.attempts, 3);

      // Per ChatConnectionCubit.retry() — the LEAD pin documents this as the
      // canonical reset contract: status → pending, attempts → 0.
      msg = msg.copyWith(status: ChatMessageStatus.pending, attempts: 0);
      expect(msg.status, ChatMessageStatus.pending);
      expect(msg.attempts, 0);
    });

    test('attempts increments preserve clientId and serverId', () {
      var msg = _msg('c-4', serverId: 's-4');
      for (var i = 1; i <= 3; i++) {
        msg = msg.copyWith(attempts: i);
        expect(msg.clientId, 'c-4');
        expect(msg.serverId, 's-4');
        expect(msg.attempts, i);
      }
    });
  });

  group('ChatOutbox.markFailed default impl', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('flips pending → failed without removing the entry '
        '(SharedPrefs)', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      await outbox.enqueue(_msg('b'));

      await outbox.markFailed('a');

      final loaded = await outbox.load();
      expect(loaded.length, 2, reason: 'markFailed must NOT remove the entry');
      final hit = loaded.firstWhere((m) => m.clientId == 'a');
      expect(hit.status, ChatMessageStatus.failed);
      // Sibling entry stays untouched.
      final other = loaded.firstWhere((m) => m.clientId == 'b');
      expect(other.status, ChatMessageStatus.pending);
    });

    test('flips pending → failed without removing the entry '
        '(InMemory)', () async {
      final outbox = InMemoryChatOutbox([_msg('a'), _msg('b')]);
      await outbox.markFailed('a');
      final loaded = await outbox.load();
      expect(loaded.length, 2);
      expect(
        loaded.firstWhere((m) => m.clientId == 'a').status,
        ChatMessageStatus.failed,
      );
      expect(
        loaded.firstWhere((m) => m.clientId == 'b').status,
        ChatMessageStatus.pending,
      );
    });

    test('is a no-op for unknown clientId (SharedPrefs)', () async {
      final prefs = await SharedPreferences.getInstance();
      final outbox = SharedPrefsChatOutbox(prefs: prefs);
      await outbox.enqueue(_msg('a'));
      await outbox.markFailed('missing');
      final loaded = await outbox.load();
      expect(loaded.length, 1);
      expect(loaded.single.status, ChatMessageStatus.pending);
    });

    test('is a no-op for unknown clientId (InMemory)', () async {
      final outbox = InMemoryChatOutbox([_msg('a')]);
      await outbox.markFailed('missing');
      final loaded = await outbox.load();
      expect(loaded.single.status, ChatMessageStatus.pending);
    });

    test('preserves attempts when flipping to failed', () async {
      final outbox = InMemoryChatOutbox([
        _msg('a', attempts: 2),
      ]);
      await outbox.markFailed('a');
      final loaded = await outbox.load();
      expect(loaded.single.status, ChatMessageStatus.failed);
      // Per the retry contract: only the cubit's retry() zeroes attempts.
      // markFailed alone preserves the counter so the UI can show "tried N
      // times".
      expect(loaded.single.attempts, 2);
    });
  });
}
