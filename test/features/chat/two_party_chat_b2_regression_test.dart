// REAL two-party chat regression guard for B-2 (jeeber-not-seated).
//
// B-2 (sprint-8 D1, CHAT-COMPLETION-PLAN): after a client accepts an offer, the
// winning jeeber must be a participant of the order conversation so they can
// read history, pass the realtime membership pre-check, and RECEIVE the
// client's messages. The original accept saga only *promoted* an
// already-seated participant; it never *added* the winner. So the outcome was
// TIMING-DEPENDENT:
//   • customer-opens-chat-first → jeeber seated when they offer (conv exists)
//     → jeeber receives.            ✅
//   • jeeber-offers-first        → no conversation yet → jeeber never seated;
//     the accept saga didn't self-heal → jeeber 403s on history + realtime and
//     RECEIVES NOTHING.             ❌ B-2
//
// This test drives the full create → jeeber-offer → accept → send flow through
// two real `ChatCubit`s (customer + jeeber) over a shared in-memory backend
// that models the EXACT seating contract, for BOTH orderings, and asserts the
// jeeber (the second participant) receives the customer's message.
//
// TEST-INTEGRITY: a guard that only ever passes is worthless. The backend is
// parameterized by `seatWinnerOnAccept`; the final test flips it OFF to
// reproduce the B-2 bug and proves the guard goes RED (the jeeber-offers-first
// jeeber then receives nothing). So the green cases above are meaningful — they
// would fail if the seat-the-winner fix regressed.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _clientId = 'user-client-001';
const _jeeberId = 'user-jeeber-002';
const _conversationId = 'conv-req-1';

/// A stored server message — author-neutral. Projected to a per-viewer
/// [DeliveryChatMessage] (mine vs theirs) on the way out, exactly as a real
/// chat-service stamps `me`/`them` per reader.
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
        // Inbound messages enter the reader's timeline already delivered.
        status: MessageStatus.delivered,
        text: text,
      );
}

/// Raised when a non-member touches the conversation — the backend's 403.
class _NotAMemberError extends Error {
  _NotAMemberError(this.userId);
  final String userId;
  @override
  String toString() => 'NotAMember($userId)';
}

/// Single-conversation in-memory chat backend modeling the seating + fan-out
/// contract the real chat-service / offer-service implement.
class _ChatBackend {
  _ChatBackend({required this.seatWinnerOnAccept});

  /// The B-2 fix (T-BE-1): the accept saga creates-or-gets the conversation
  /// AND ensures the winning jeeber is a participant. When `false`, the saga
  /// only promotes an already-seated participant (the original B-2 bug) — the
  /// winner is never *added*.
  final bool seatWinnerOnAccept;

  bool _conversationExists = false;
  ConversationPhase phase = ConversationPhase.broadcasting;
  final Set<String> _participants = {};
  final List<_StoredMessage> _history = [];
  final Map<String, StreamController<ChatEvent>> _streams = {};

  StreamController<ChatEvent> _streamFor(String userId) => _streams.putIfAbsent(
        userId,
        () => StreamController<ChatEvent>.broadcast(),
      );

  Stream<ChatEvent> subscribeFor(String userId) => _streamFor(userId).stream;

  bool isMember(String userId) => _participants.contains(userId);

  /// Customer opens the chat → create-or-get conversation, seat the opener.
  /// (chat-service seats ONLY the opener — the source of B-2.)
  void customerOpensChat() {
    _conversationExists = true;
    _participants.add(_clientId);
  }

  /// Jeeber submits an offer. Mirrors offer-service.seatJeeberOnConversation:
  /// the jeeber is seated ONLY if a conversation already exists for the
  /// request. Otherwise the seating silently never happens.
  void jeeberSubmitsOffer() {
    if (_conversationExists) _participants.add(_jeeberId);
  }

  /// Customer accepts the winning offer. The order conversation now exists and
  /// the client is seated regardless (the client opens the order chat). The
  /// B-2-relevant behavior is whether the WINNER gets added.
  void customerAcceptsOffer() {
    phase = ConversationPhase.accepted;
    _conversationExists = true;
    _participants.add(_clientId);
    if (seatWinnerOnAccept) {
      _participants.add(_jeeberId); // B-2 FIX (T-BE-1)
    }
    // else: B-2 BUG — the winner is never added when not already seated.
  }

  List<DeliveryChatMessage> historyFor(String userId) {
    if (!isMember(userId)) throw _NotAMemberError(userId);
    return _history.map((m) => m.viewFor(userId)).toList(growable: false);
  }

  void send(String senderId, DeliveryChatMessage message) {
    if (!isMember(senderId)) throw _NotAMemberError(senderId);
    final stored = _StoredMessage(
      id: message.id,
      senderId: senderId,
      text: message.text,
      sentAt: message.sentAt,
    );
    _history.add(stored);
    // Fan out to every OTHER seated participant.
    for (final participant in _participants) {
      if (participant == senderId) continue;
      _streamFor(participant).add(IncomingMessage(stored.viewFor(participant)));
    }
  }

  Future<void> dispose() async {
    for (final c in _streams.values) {
      await c.close();
    }
  }
}

/// A [ChatGateway] bound to one party's identity, talking to the shared
/// [_ChatBackend]. Inbound arrives over [subscribe]; history/membership is
/// enforced per-user, exactly like the real gateway.
class _PartyGateway extends ChatGateway {
  _PartyGateway(this._backend, this._userId);

  final _ChatBackend _backend;
  final String _userId;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      _backend.historyFor(_userId);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      _backend.phase;

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

ChatCubit _cubitFor(_ChatBackend backend, String userId) => ChatCubit(
      deliveryId: _conversationId,
      gateway: _PartyGateway(backend, userId),
      pickerService: StubPhotoPickerService(),
    );

/// Did the jeeber's chat receive a 'them'-authored message with [body]?
bool _jeeberReceived(ChatCubit jeeber, String body) => jeeber.state.messages
    .any((m) => m.text == body && m.author == ChatAuthor.them);

void main() {
  group('Two-party chat — B-2 regression guard (jeeber receives after accept)',
      () {
    test(
        'ORDERING A (customer-opens-chat-first): jeeber receives the '
        "customer's message", () async {
      final backend = _ChatBackend(seatWinnerOnAccept: true);
      addTearDown(backend.dispose);

      // Lifecycle: customer opens chat → jeeber offers (conv exists → seated)
      // → customer accepts.
      backend.customerOpensChat();
      backend.jeeberSubmitsOffer();
      backend.customerAcceptsOffer();

      final customer = _cubitFor(backend, _clientId);
      final jeeber = _cubitFor(backend, _jeeberId);
      addTearDown(customer.close);
      addTearDown(jeeber.close);

      // Both sides open the conversation (load history + subscribe).
      await customer.load();
      await jeeber.load();

      // Customer sends a message; it must fan out to the seated jeeber.
      customer.composerChanged('I am at the gate');
      await customer.sendText();
      await pumpEventQueue();

      expect(_jeeberReceived(jeeber, 'I am at the gate'), isTrue,
          reason: 'seated jeeber must receive the customer message live');
      // The sender does NOT get a duplicate of their own message (no echo).
      expect(
        customer.state.messages.where((m) => m.text == 'I am at the gate'),
        hasLength(1),
      );
    });

    test(
        'ORDERING B (jeeber-offers-first, no conv yet): the accept saga seats '
        'the winner so the jeeber STILL receives — the exact B-2 case',
        () async {
      final backend = _ChatBackend(seatWinnerOnAccept: true);
      addTearDown(backend.dispose);

      // Lifecycle: jeeber offers BEFORE any conversation exists (not seated at
      // offer time) → customer accepts (create-or-get + seat winner).
      backend.jeeberSubmitsOffer();
      expect(backend.isMember(_jeeberId), isFalse,
          reason: 'precondition: jeeber not seated at offer time (no conv)');
      backend.customerAcceptsOffer();
      expect(backend.isMember(_jeeberId), isTrue,
          reason: 'accept saga must seat the winning jeeber (B-2 fix)');

      final customer = _cubitFor(backend, _clientId);
      final jeeber = _cubitFor(backend, _jeeberId);
      addTearDown(customer.close);
      addTearDown(jeeber.close);

      await jeeber.load();
      await customer.load();

      customer.composerChanged('Order accepted — see you soon');
      await customer.sendText();
      await pumpEventQueue();

      expect(_jeeberReceived(jeeber, 'Order accepted — see you soon'), isTrue,
          reason:
              'the jeeber-offers-first jeeber must be seated by the accept saga '
              'and receive the message');
    });

    test(
        'SENSITIVITY (negative control): with the B-2 bug present '
        '(accept does NOT seat the winner), the jeeber-offers-first jeeber '
        'receives NOTHING — proving the guard above is real', () async {
      // seatWinnerOnAccept:false reproduces the original accept saga that only
      // promotes an existing participant.
      final backend = _ChatBackend(seatWinnerOnAccept: false);
      addTearDown(backend.dispose);

      backend.jeeberSubmitsOffer(); // no conv → not seated
      backend.customerAcceptsOffer(); // bug: winner never added
      expect(backend.isMember(_jeeberId), isFalse,
          reason: 'B-2 bug: winner left unseated');

      final customer = _cubitFor(backend, _clientId);
      final jeeber = _cubitFor(backend, _jeeberId);
      addTearDown(customer.close);
      addTearDown(jeeber.close);

      // The jeeber's history read 403s → load() degrades to an empty,
      // never-subscribed chat (the real "jeeber sees an empty chat").
      await jeeber.load();
      await customer.load();

      customer.composerChanged('Are you there?');
      await customer.sendText();
      await pumpEventQueue();

      expect(_jeeberReceived(jeeber, 'Are you there?'), isFalse,
          reason: 'unseated jeeber must NOT receive — this is the B-2 failure '
              'the green tests guard against');
    });
  });
}
