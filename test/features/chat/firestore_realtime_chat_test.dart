// THE GATE for the Firestore realtime chat transport (b02).
//
// The claim under test, in the owner's words: *"The mobile should subscribe to
// Firestore and the backend should never subscribe to firestore, the backend
// should only store in firestore and that will automatically updated on the
// mobile."*
//
// Operationally that means ONE thing has to be true and it is the thing every
// previous chat "fix" got wrong: **the message CONTENT arrives in the stream, so
// the client renders from the snapshot and never refetches.** A transport that
// notifies and then re-reads over HTTP is the push→refetch path this work
// exists to delete — it cost one whole `GET /v1/conversations/{id}/messages` per
// inbound message.
//
// So the load-bearing assertion in this file is a CONJUNCTION, and both halves
// matter:
//
//     the text is on screen   AND   loadHistory was not called again
//
// Asserting only the first half is I-06 in reverse: "the row rendered" says
// nothing about what paid for it. Asserting only the second is I-15's blind
// spot: "no fetch happened" is equally true of a transport that delivered
// nothing at all.
//
// WHAT IS REAL AND WHAT IS FAKED. The Firestore SDK boundary is faked and
// NOTHING ELSE is. `_FakeRealtimeSource` hands raw PascalCase documents — the
// exact shape `FirestoreConversationStore.AddMessageAsync` writes — to the REAL
// `FirestoreChatMessageMapper` and the REAL `ChatRealtimeProjector`, and the
// events go through the REAL `RealtimeChatGateway`, the REAL `ChatCubit` and the
// REAL `ChatScreen`. If the PascalCase→wire normalisation is wrong, or the
// payload-string decode is wrong, or the codec drops the kind, these tests fail.
//
// NEGATIVE CONTROLS. I-14: a green suite proves nothing about a test's POWER.
// Every positive assertion here is paired with a case that must fail if the
// transport is doing nothing:
//   * `renders NOTHING when the stream is silent` — the same screen, the same
//     nonce, no document emitted. If this ever finds the text, the text is
//     coming from somewhere other than the stream and the gate is vacuous.
//   * `a push DOES drive a re-pull once the stream reports itself dead` — proves
//     the suppression is conditional on liveness and not just switched off,
//     which is exactly the failure mode I-13 recorded (`debugPositionStreamWired`
//     read `true` on a dead SSE stream, so its guard never fired again).

library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/data/firestore_chat_message_mapper.dart';
import 'package:jeeb_mobile/features/chat/data/realtime_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_realtime_source.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../../support/sync_app_localizations.dart';

const _me = 'user-client-001';
const _them = 'user-jeeber-002';
const _conversationId = 'conv-fs-1';

/// A chat-service message document, in the shape
/// `FirestoreConversationStore.AddMessageAsync` writes it: the native
/// `[FirestoreData]` POCO mapper, so the Firestore field names ARE the C#
/// property names (`ConversationMessage` + `BaseModel`).
Map<String, Object?> _doc({
  required String id,
  required String authorId,
  String kind = 'text',
  String? body,
  String? payload,
  DateTime? createdAt,
  bool isDeleted = false,
}) =>
    <String, Object?>{
      'Guid': id,
      'ConversationId': _conversationId,
      'AuthorId': authorId,
      'Kind': kind,
      'Subtype': '',
      'Audience': 'all',
      'Body': ?body,
      'Payload': ?payload,
      'IdempotencyKey': 'idem-$id',
      'CreatedAt': createdAt ?? DateTime.utc(2026, 7, 28, 9, 5),
      'IsDeleted': isDeleted,
      'IsActive': true,
    };

/// Stands in for `FirestoreChatRealtimeSource` at exactly one seam: instead of
/// `cloud_firestore` producing the snapshot, the test does. Everything after
/// that point — mapping, validation, decode, event shape — is production code.
class _FakeRealtimeSource implements ChatRealtimeSource {
  _FakeRealtimeSource({String currentUserId = _me})
      : _projector = ChatRealtimeProjector(
          mapRow: FirestoreChatMessageMapper(currentUserId: currentUserId).map,
        );

  final ChatRealtimeProjector _projector;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  int subscribeCalls = 0;
  bool disposed = false;

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    subscribeCalls++;
    return _events.stream;
  }

  /// The channel reports that a snapshot has ARRIVED — the only thing that may
  /// set liveness (I-13: arming a listener is not evidence it works).
  void goLive() =>
      _events.add(const RealtimeTransportChanged(live: true, reason: 'first_snapshot'));

  void goDead(String reason) =>
      _events.add(RealtimeTransportChanged(live: false, reason: reason));

  /// The server wrote a document; Firestore pushed it down the open channel.
  void deliver(Map<String, Object?> doc, {String? docId, bool removed = false}) {
    final changes = <RealtimeDocChange>[
      RealtimeDocChange(
        id: docId ?? (doc['Guid'] as String? ?? ''),
        data: doc,
        removed: removed,
      ),
    ];
    for (final event in _projector.project(changes)) {
      _events.add(event);
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!_events.isClosed) await _events.close();
  }
}

/// The HTTP half. Counts every wire read so a test can assert what a rendered
/// message COST, not merely that it rendered.
class _CountingHttpGateway extends ChatGateway {
  _CountingHttpGateway([this.history = const <DeliveryChatMessage>[]]);

  List<DeliveryChatMessage> history;
  int loadHistoryCalls = 0;
  int loadPhaseCalls = 0;
  int subscribeCalls = 0;

  final StreamController<ChatEvent> _unused =
      StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    loadHistoryCalls++;
    return List<DeliveryChatMessage>.from(history);
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    loadPhaseCalls++;
    return ConversationPhase.accepted;
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  /// Reached exactly ONCE through [RealtimeChatGateway], which MERGES this leg
  /// rather than replacing it — the decorator swaps the message TRANSPORT, but
  /// this stream is also the only carrier for the gateway's synthetic
  /// `PhaseChanged(accepted)`. `subscribeCalls` is therefore an open-count, not
  /// a "was HTTP used" signal; what proves the realtime source is carrying the
  /// thread is [loadHistoryCalls] not moving while messages arrive.
  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    subscribeCalls++;
    return _unused.stream;
  }

  Future<void> dispose() => _unused.close();
}

({
  _CountingHttpGateway http,
  _FakeRealtimeSource realtime,
  RealtimeChatGateway gateway,
}) _harness({List<DeliveryChatMessage> history = const []}) {
  final http = _CountingHttpGateway(List.of(history));
  final realtime = _FakeRealtimeSource();
  addTearDown(http.dispose);
  addTearDown(realtime.dispose);
  return (
    http: http,
    realtime: realtime,
    gateway: RealtimeChatGateway(inner: http, realtime: realtime),
  );
}

ChatCubit _cubit(ChatGateway gateway, {Stream<void>? signals}) {
  final cubit = ChatCubit(
    deliveryId: _conversationId,
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    refreshSignals: signals,
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('THE GATE — a message renders FROM THE STREAM with NO HTTP call', () {
    testWidgets('the counterpart line arrives in the snapshot and paints',
        (tester) async {
      const nonce = 'FS-GATE-4417 on my way';
      final h = _harness();

      await tester.pumpWidget(
        wrapForTest(
          ChatScreen(
            deliveryId: _conversationId,
            counterpartName: 'Sam',
            gateway: h.gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The cold mount reads history over HTTP exactly once. That read is the
      // BASELINE every later assertion is measured against; the thread is empty
      // so it cannot be the source of the nonce.
      expect(h.http.loadHistoryCalls, 1, reason: 'cold mount');
      expect(find.text(nonce), findsNothing, reason: 'nothing has arrived yet');
      // CHANGED, and deliberately — this assertion used to demand 0 and that was
      // pinning a bug. `RealtimeChatGateway.subscribe` now MERGES both legs
      // instead of replacing the inner one, because the inner stream is the only
      // carrier for `DioChatGateway`'s synthetic
      // `PhaseChanged(accepted, deliveryId:…)` (`dio_chat_gateway.dart:470-474`)
      // and dropping it turns the customer's Accept tap into a no-op.
      //
      // What the old 0 was REALLY defending — "the realtime source, not HTTP, is
      // carrying the thread" — is not measured by this counter at all: opening a
      // stream costs nothing and delivers nothing. It is measured by
      // `loadHistoryCalls` staying at its cold-mount baseline while the nonce
      // arrives, which is asserted above and below and is untouched.
      expect(
        h.http.subscribeCalls,
        1,
        reason: 'the inner leg is merged, opened exactly once, never twice',
      );
      expect(h.realtime.subscribeCalls, 1);

      // The backend wrote the document. Firestore pushed it. Nothing on the
      // device asked for it.
      h.realtime.goLive();
      h.realtime.deliver(_doc(id: 'm-1', authorId: _them, body: nonce));
      await tester.pumpAndSettle();

      expect(
        find.text(nonce),
        findsOneWidget,
        reason: 'the message CONTENT came down the stream and rendered',
      );
      expect(
        h.http.loadHistoryCalls,
        1,
        reason:
            'STILL the cold mount — rendering that message cost ZERO wire reads',
      );
      expect(h.http.loadPhaseCalls, 1, reason: 'also unchanged');
    });

    // NEGATIVE CONTROL / MUTATION PROOF, permanent.
    //
    // Identical to the case above except the stream emits nothing. If the nonce
    // is ever found here, it is not the stream that put it on screen and the
    // gate above proves nothing. This is the "stub the stream to emit nothing;
    // the test must fail" mutation, kept in the suite so it cannot rot.
    testWidgets('renders NOTHING when the stream is silent', (tester) async {
      const nonce = 'FS-GATE-4417 on my way';
      final h = _harness();

      await tester.pumpWidget(
        wrapForTest(
          ChatScreen(
            deliveryId: _conversationId,
            counterpartName: 'Sam',
            gateway: h.gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      h.realtime.goLive();
      // …and no `deliver`.
      await tester.pumpAndSettle();

      expect(
        find.text(nonce),
        findsNothing,
        reason: 'a live channel that carried no document must paint no message',
      );
      expect(h.http.loadHistoryCalls, 1);
    });

    testWidgets('a structured payload arrives whole — no refetch to resolve it',
        (tester) async {
      // `ConversationMessage.Payload` is `public string`: a structured message
      // is stored as JSON TEXT. The HTTP hop parses it back into an object; the
      // document does not, so the mapper must. If this decode were missing the
      // bubble would render empty and the only way to fill it would be — a
      // refetch.
      final h = _harness();

      await tester.pumpWidget(
        wrapForTest(
          ChatScreen(
            deliveryId: _conversationId,
            counterpartName: 'Sam',
            gateway: h.gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      h.realtime.goLive();
      h.realtime.deliver(_doc(
        id: 'm-sys',
        authorId: _them,
        kind: 'system',
        payload: '{"text":"FS-GATE-SYSTEM-9001"}',
      ));
      await tester.pumpAndSettle();

      expect(find.text('FS-GATE-SYSTEM-9001'), findsOneWidget);
      expect(h.http.loadHistoryCalls, 1, reason: 'zero wire reads');
    });
  });

  group('the push stops driving a reload while the stream is live', () {
    test('a chat push costs ZERO reads once a snapshot has arrived', () async {
      final h = _harness();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = _cubit(h.gateway, signals: bus.stream);

      await cubit.load();
      expect(h.http.loadHistoryCalls, 1);
      expect(cubit.debugPushRefreshWired, isTrue);
      expect(cubit.debugRealtimeLive, isFalse, reason: 'nothing arrived yet');

      h.realtime.goLive();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.debugRealtimeLive, isTrue);

      // Three inbound messages, each with its own FCM push. Before this change
      // that was three whole-thread `GET /v1/conversations/{id}/messages`.
      for (var i = 1; i <= 3; i++) {
        h.realtime.deliver(_doc(
          id: 'm-$i',
          authorId: _them,
          body: 'line $i',
          createdAt: DateTime.utc(2026, 7, 28, 9, i),
        ));
        bus.add(null);
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        cubit.state.messages.map((m) => m.text),
        ['line 1', 'line 2', 'line 3'],
        reason: 'all three arrived — down the stream',
      );
      expect(
        h.http.loadHistoryCalls,
        1,
        reason: 'three messages, three pushes, ZERO extra wire reads',
      );
      expect(cubit.debugPushRefreshSuppressedCount, 3);
      expect(cubit.debugPushRefreshCount, 0);
    });

    // The other direction. Without this the suppression above is
    // indistinguishable from having deleted the fallback outright — which is
    // exactly the state that would leave a thread with no inbound path at all
    // when the channel cannot open (today: no Firebase identity).
    test('a push DOES drive a re-pull once the stream reports itself dead',
        () async {
      final h = _harness();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = _cubit(h.gateway, signals: bus.stream);

      await cubit.load();
      h.realtime.goLive();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.debugRealtimeLive, isTrue);

      h.realtime.goDead('stream_error');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.debugRealtimeLive, isFalse);

      h.http.history = <DeliveryChatMessage>[
        DeliveryChatMessage.text(
          id: 'm-http',
          author: ChatAuthor.them,
          sentAt: DateTime.utc(2026, 7, 28, 9, 30),
          status: MessageStatus.delivered,
          text: 'arrived over HTTP',
        ),
      ];
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        h.http.loadHistoryCalls,
        2,
        reason: 'a dead channel must hand the thread back to the HTTP fallback',
      );
      expect(cubit.state.messages.map((m) => m.text), ['arrived over HTTP']);
      expect(cubit.debugPushRefreshCount, 1);
    });

    test('a gateway with no realtime transport is unaffected', () async {
      // The degradation that matters most: every existing host still gets the
      // push-driven read, because a gateway that never emits
      // RealtimeTransportChanged leaves `debugRealtimeLive` false forever.
      final http = _CountingHttpGateway();
      addTearDown(http.dispose);
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = _cubit(http, signals: bus.stream);

      await cubit.load();
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.debugRealtimeLive, isFalse);
      expect(http.loadHistoryCalls, 2, reason: 'unchanged behaviour');
      expect(cubit.debugPushRefreshSuppressedCount, 0);
    });
  });

  group('the stream folds into the SAME reconciliation as every other path',
      () {
    test('the sender own-echo does not double the bubble', () async {
      // Firestore fans the sender's OWN document back down their own channel.
      // It carries the SERVER id, which never equals the optimistic local id, so
      // an id-only check would append a second copy of the user's own message.
      final h = _harness();
      final cubit = _cubit(h.gateway);
      await cubit.load();
      h.realtime.goLive();
      await Future<void>.delayed(Duration.zero);

      cubit.composerChanged('gate code is 4417');
      await cubit.sendText();
      expect(cubit.state.messages.length, 1);

      h.realtime.deliver(_doc(
        id: 'server-id-xyz',
        authorId: _me,
        body: 'gate code is 4417',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.messages.length,
        1,
        reason: 'the server document reconciled onto the optimistic bubble',
      );
      expect(cubit.state.messages.single.isMine, isTrue);
    });

    test('a document redelivered in a later snapshot is a no-op', () async {
      // `docChanges` re-reports a document on `modified`. The cubit's id-dedupe
      // is what stops that becoming a duplicate bubble.
      final h = _harness();
      final cubit = _cubit(h.gateway);
      await cubit.load();
      h.realtime.goLive();

      final doc = _doc(id: 'm-1', authorId: _them, body: 'once');
      h.realtime.deliver(doc);
      h.realtime.deliver(doc);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.messages.map((m) => m.text), ['once']);
    });

    test('a removed document is never decoded as an arrival', () async {
      final h = _harness();
      final cubit = _cubit(h.gateway);
      await cubit.load();
      h.realtime.goLive();

      h.realtime.deliver(
        _doc(id: 'm-gone', authorId: _them, body: 'should not appear'),
        removed: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.messages, isEmpty);
    });

    test('one unrenderable document does not kill the channel', () async {
      final h = _harness();
      final cubit = _cubit(h.gateway);
      await cubit.load();
      h.realtime.goLive();

      // No author — fails `ChatMessageCodec.isValidRow`.
      h.realtime.deliver(<String, Object?>{
        'Guid': 'm-bad',
        'Kind': 'text',
        'Body': 'orphan',
      });
      h.realtime.deliver(_doc(id: 'm-ok', authorId: _them, body: 'still here'));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.messages.map((m) => m.text), ['still here']);
      expect(cubit.debugRealtimeLive, isTrue, reason: 'channel survived');
    });
  });
}
