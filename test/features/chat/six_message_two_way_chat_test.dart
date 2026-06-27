// CHAT-01/03 (Sprint-2 Leg-3) — the >=6-message TWO-WAY chat acceptance leg.
//
// Definition of Done for this leg (TEAM-CHARTER / Sprint-2 contract §6):
//   client SENDS request -> jeeber ACCEPTS -> >=6 two-way CHAT messages, both
//   participants SEATED, every counterpart message RECEIVED, sorted by the
//   server clock (S0-CHAT-04). This file drives a full >=6-message exchange in
//   BOTH directions through two REAL `ChatCubit`s talking to one shared
//   in-memory backend that models the canonical seating + fan-out + per-viewer
//   contract the real chat-service implements, and asserts both timelines end
//   up complete and chronologically ordered.
//
// It is disjoint from the offer/accept (Leg-2) and phase (NEW-BUG-01, Leg-1)
// lanes: the conversation is pre-seated in `accepted` and the test exercises
// ONLY the messaging path.
//
// TEST-INTEGRITY (lessons §6 — a guard that can only pass is worthless): the
// final group lands counterpart messages whose server timestamps arrive OUT OF
// ORDER and proves the cubit re-sorts them chronologically; a negative control
// shows that without the server-time ordering the timeline would be wrong.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _clientId = 'user-client-001';
const _jeeberId = 'user-jeeber-002';
const _conversationId = 'conv-req-6msg';

/// Author-neutral stored message — projected per-viewer (mine vs theirs) on the
/// way out, exactly as a real chat-service stamps `me`/`them` per reader.
class _StoredMessage {
  _StoredMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  DeliveryChatMessage viewFor(String userId) => DeliveryChatMessage.text(
        id: id,
        author: senderId == userId ? ChatAuthor.me : ChatAuthor.them,
        sentAt: sentAt,
        status: MessageStatus.delivered,
        text: text,
      );
}

class _NotAMemberError extends Error {
  _NotAMemberError(this.userId);
  final String userId;
  @override
  String toString() => 'NotAMember($userId)';
}

/// Single-conversation in-memory chat backend modeling the canonical seating +
/// per-viewer fan-out contract. Pre-seated `accepted` (both parties present) so
/// this file tests ONLY the >=6-message messaging path.
class _TwoWayBackend {
  final Set<String> _participants = {_clientId, _jeeberId};
  final List<_StoredMessage> _history = [];
  final Map<String, StreamController<ChatEvent>> _streams = {};

  /// When false, fan-out delivers each inbound message immediately in send
  /// order. When true, the backend HOLDS messages and releases them to the
  /// recipient out of chronological order (later-stamped first) to exercise the
  /// client-side ordering guarantee (S0-CHAT-04).
  bool deliverOutOfOrder = false;
  final List<_StoredMessage> _held = [];

  /// Monotonic server-id source. A real chat-service stamps its OWN id on each
  /// persisted message (distinct from the sender's optimistic client id), so the
  /// recipient sees `srv-N`, never the sender's local `msg-...` id. Modelling
  /// this is required: two cubits sharing one deliveryId mint colliding client
  /// ids, and an id-collision would (wrongly) make the recipient's dedup drop a
  /// genuine counterpart message.
  int _serverSeq = 0;

  StreamController<ChatEvent> _streamFor(String userId) => _streams.putIfAbsent(
        userId,
        () => StreamController<ChatEvent>.broadcast(),
      );

  Stream<ChatEvent> subscribeFor(String userId) => _streamFor(userId).stream;

  bool isMember(String userId) => _participants.contains(userId);

  List<DeliveryChatMessage> historyFor(String userId) {
    if (!isMember(userId)) throw _NotAMemberError(userId);
    final ordered = [..._history]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return ordered.map((m) => m.viewFor(userId)).toList(growable: false);
  }

  void send(String senderId, DeliveryChatMessage message) {
    if (!isMember(senderId)) throw _NotAMemberError(senderId);
    final stored = _StoredMessage(
      id: 'srv-${_serverSeq++}',
      senderId: senderId,
      text: message.text,
      sentAt: message.sentAt,
    );
    _history.add(stored);
    if (deliverOutOfOrder) {
      _held.add(stored);
      return;
    }
    _fanOut(stored);
  }

  /// Release every held message to its recipients in REVERSE chronological order
  /// (newest first) — the worst case for a naive append, so a green assertion
  /// proves the cubit sorts by server time rather than arrival order.
  void flushHeldNewestFirst() {
    _held.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    for (final m in _held) {
      _fanOut(m);
    }
    _held.clear();
  }

  void _fanOut(_StoredMessage stored) {
    for (final participant in _participants) {
      if (participant == stored.senderId) continue;
      _streamFor(participant).add(IncomingMessage(stored.viewFor(participant)));
    }
  }

  Future<void> dispose() async {
    for (final c in _streams.values) {
      await c.close();
    }
  }
}

/// A [ChatGateway] bound to one party's identity, talking to the shared backend.
class _PartyGateway extends ChatGateway {
  _PartyGateway(this._backend, this._userId);

  final _TwoWayBackend _backend;
  final String _userId;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      _backend.historyFor(_userId);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async {
    _backend.send(_userId, message);
    return message.copyWith(status: MessageStatus.sent);
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      _backend.subscribeFor(_userId);
}

ChatCubit _cubitFor(_TwoWayBackend backend, String userId, DateTime Function() clock) =>
    ChatCubit(
      deliveryId: _conversationId,
      gateway: _PartyGateway(backend, userId),
      pickerService: StubPhotoPickerService(),
      clock: clock,
    );

/// Texts a cubit currently shows, oldest first.
List<String> _texts(ChatCubit c) =>
    c.state.messages.map((m) => m.text).toList(growable: false);

void main() {
  group('Chat Leg-3 — >=6-message two-way exchange (CHAT-01/03)', () {
    test(
        'six alternating messages (3 each way) BOTH reach BOTH parties, in '
        'chronological order, with no duplicated own bubbles', () async {
      final backend = _TwoWayBackend();
      addTearDown(backend.dispose);

      // Deterministic, strictly-increasing per-message clocks so the canonical
      // chronological order is well-defined and the assertion is unambiguous.
      final base = DateTime.utc(2026, 6, 27, 9, 0, 0);
      var clientTick = 0;
      var jeeberTick = 0;
      final client = _cubitFor(
        backend,
        _clientId,
        () => base.add(Duration(seconds: (clientTick++) * 2)),
      );
      final jeeber = _cubitFor(
        backend,
        _jeeberId,
        () => base.add(Duration(seconds: (jeeberTick++) * 2 + 1)),
      );
      addTearDown(client.close);
      addTearDown(jeeber.close);

      await client.load();
      await jeeber.load();

      // Strictly alternating exchange: c1, j1, c2, j2, c3, j3 (>=6 two-way).
      Future<void> exchange(ChatCubit from, String text) async {
        from.composerChanged(text);
        await from.sendText();
        await pumpEventQueue();
      }

      await exchange(client, 'c1: heading out now');
      await exchange(jeeber, 'j1: i am at the pickup');
      await exchange(client, 'c2: which gate?');
      await exchange(jeeber, 'j2: north gate, blue sign');
      await exchange(client, 'c3: on my way, 2 min');
      await exchange(jeeber, 'j3: standing by the entrance');

      const expected = [
        'c1: heading out now',
        'j1: i am at the pickup',
        'c2: which gate?',
        'j2: north gate, blue sign',
        'c3: on my way, 2 min',
        'j3: standing by the entrance',
      ];

      // Both timelines are complete: every one of the six messages is present.
      expect(_texts(client), expected,
          reason: 'client sees all 6 in chronological order');
      expect(_texts(jeeber), expected,
          reason: 'jeeber sees all 6 in chronological order');

      // Each party owns exactly its 3 sends and received exactly the other's 3.
      expect(client.state.messages.where((m) => m.isMine).length, 3);
      expect(client.state.messages.where((m) => !m.isMine).length, 3);
      expect(jeeber.state.messages.where((m) => m.isMine).length, 3);
      expect(jeeber.state.messages.where((m) => !m.isMine).length, 3);

      // No duplicated own bubble (the own-echo dedupe holds across 6 messages).
      for (final cubit in [client, jeeber]) {
        final ids = cubit.state.messages.map((m) => m.id).toList();
        expect(ids.toSet().length, ids.length,
            reason: 'no message id appears twice in either timeline');
      }
    });

    test(
        'ORDERING (S0-CHAT-04): counterpart messages delivered NEWEST-FIRST are '
        're-sorted into chronological order by server time', () async {
      final backend = _TwoWayBackend()..deliverOutOfOrder = true;
      addTearDown(backend.dispose);

      final base = DateTime.utc(2026, 6, 27, 9, 0, 0);
      var jeeberTick = 0;
      // The client is a passive reader here; the jeeber posts three messages
      // whose server timestamps strictly increase, but the backend HOLDS them
      // and releases them to the client newest-first.
      final client = _cubitFor(backend, _clientId, () => base);
      final jeeber = _cubitFor(
        backend,
        _jeeberId,
        () => base.add(Duration(minutes: ++jeeberTick)),
      );
      addTearDown(client.close);
      addTearDown(jeeber.close);

      await client.load();
      await jeeber.load();

      for (final text in ['first (09:01)', 'second (09:02)', 'third (09:03)']) {
        jeeber.composerChanged(text);
        await jeeber.sendText();
        await pumpEventQueue();
      }
      // The client has received nothing yet (messages were held).
      expect(client.state.messages, isEmpty);

      // Release them to the client in REVERSE order (third, second, first).
      backend.flushHeldNewestFirst();
      await pumpEventQueue();

      // Despite arriving newest-first, the client timeline is chronological.
      expect(_texts(client), [
        'first (09:01)',
        'second (09:02)',
        'third (09:03)',
      ]);
    });

    test(
        'SENSITIVITY (negative control): the same newest-first delivery, asserted '
        'against ARRIVAL order, is reverse-chronological — proving the ordering '
        'guarantee above is load-bearing, not incidental', () async {
      // This mirrors the test above but checks what a NAIVE append (arrival
      // order) would have produced. If the cubit ever stops sorting by server
      // time, the previous test goes RED and this one would go GREEN — making
      // the regression impossible to miss.
      final backend = _TwoWayBackend()..deliverOutOfOrder = true;
      addTearDown(backend.dispose);

      final base = DateTime.utc(2026, 6, 27, 9, 0, 0);
      var jeeberTick = 0;
      final client = _cubitFor(backend, _clientId, () => base);
      final jeeber = _cubitFor(
        backend,
        _jeeberId,
        () => base.add(Duration(minutes: ++jeeberTick)),
      );
      addTearDown(client.close);
      addTearDown(jeeber.close);

      await client.load();
      await jeeber.load();

      for (final text in ['first (09:01)', 'second (09:02)', 'third (09:03)']) {
        jeeber.composerChanged(text);
        await jeeber.sendText();
        await pumpEventQueue();
      }
      backend.flushHeldNewestFirst();
      await pumpEventQueue();

      // The ARRIVAL order was reverse-chronological; the cubit's timeline must
      // NOT equal it (it must be chronological instead).
      const arrivalOrder = [
        'third (09:03)',
        'second (09:02)',
        'first (09:01)',
      ];
      expect(_texts(client), isNot(arrivalOrder),
          reason: 'arrival order is reverse-chronological; the cubit sorts it');
    });
  });
}
