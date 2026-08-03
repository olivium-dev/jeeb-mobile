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

      expect(h.http.loadHistoryCalls, 1, reason: 'cold mount');
      expect(find.text(nonce), findsNothing, reason: 'nothing has arrived yet');
      expect(
        h.http.subscribeCalls,
        1,
        reason: 'the inner leg is merged, opened exactly once, never twice',
      );
      expect(h.realtime.subscribeCalls, 1);

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

      // `textContaining`, not `text`: since redesign-2026-08 the system chip
      // appends the message's own ` · HH:mm` when the row carries a server
      // timestamp (the board draws "Offer accepted · 9:12"). The SUBJECT of
      // this test is that the decoded payload reached the bubble at all, which
      // a substring match still pins exactly.
      expect(find.textContaining('FS-GATE-SYSTEM-9001'), findsOneWidget);
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
