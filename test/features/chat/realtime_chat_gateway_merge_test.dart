// REGRESSION GATE for `RealtimeChatGateway.subscribe`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/realtime_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_realtime_source.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart'
    show OfferAcceptResult;

const _conversationId = 'conv-merge-001';

/// One leg of the merge, backed by a SINGLE-subscription controller so its
/// `onCancel` fires on exactly the event this file needs to observe: the merged
/// stream's own cancellation reaching this underlying subscription.
class _Leg {
  _Leg(String label) {
    _controller = StreamController<ChatEvent>(
      onCancel: () => cancelled = true,
      onListen: () => listens += 1,
    );
    _label = label;
  }

  late final StreamController<ChatEvent> _controller;
  late final String _label;

  bool cancelled = false;
  int listens = 0;

  Stream<ChatEvent> get stream => _controller.stream;

  void emit(ChatEvent event) => _controller.add(event);

  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  String toString() => 'leg($_label)';
}

/// The realtime half. Nothing here touches `cloud_firestore`.
class _FakeSource implements ChatRealtimeSource {
  _FakeSource(this.leg);

  final _Leg leg;
  int subscribeCalls = 0;
  bool disposed = false;

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    subscribeCalls += 1;
    return leg.stream;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await leg.close();
  }
}

/// The HTTP half. `acceptOffer` reproduces the REAL `DioChatGateway` behaviour
/// under test — it pushes the synthetic `PhaseChanged` onto its own subscribe
/// stream, which is the exact event the un-merged decorator dropped.
class _FakeHttpGateway extends ChatGateway {
  _FakeHttpGateway(this.leg);

  final _Leg leg;
  int subscribeCalls = 0;

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    subscribeCalls += 1;
    return leg.stream;
  }

  @override
  bool get supportsPolling => true;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      const <DeliveryChatMessage>[];

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message;

  @override
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async {
    leg.emit(
      const PhaseChanged(ConversationPhase.accepted, deliveryId: 'del-77'),
    );
    return const OfferAcceptResult(deliveryId: 'del-77');
  }

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> fetchImageBytes(String objectRef) async =>
      throw UnimplementedError();
}

({
  _Leg realtimeLeg,
  _Leg innerLeg,
  _FakeSource source,
  _FakeHttpGateway http,
  RealtimeChatGateway gateway,
}) _harness() {
  final realtimeLeg = _Leg('realtime');
  final innerLeg = _Leg('inner');
  final source = _FakeSource(realtimeLeg);
  final http = _FakeHttpGateway(innerLeg);
  addTearDown(realtimeLeg.close);
  addTearDown(innerLeg.close);
  return (
    realtimeLeg: realtimeLeg,
    innerLeg: innerLeg,
    source: source,
    http: http,
    gateway: RealtimeChatGateway(inner: http, realtime: source),
  );
}

void main() {
  group('RealtimeChatGateway.subscribe MERGES both legs', () {
    test('the inner gateway\'s synthetic PhaseChanged(accepted) is delivered',
        () async {
      // NEGATIVE CONTROL: with `subscribe => _realtime.subscribe(id)` the inner
      final h = _harness();
      final seen = <ChatEvent>[];
      final sub = h.gateway.subscribe(_conversationId).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await h.gateway.acceptOffer(_conversationId, 'offer-1');
      await pumpEventQueue();

      expect(seen, hasLength(1));
      final event = seen.single;
      expect(event, isA<PhaseChanged>());
      expect((event as PhaseChanged).phase, ConversationPhase.accepted);
      expect(
        event.deliveryId,
        'del-77',
        reason: 'the delivery id rides on this event and nothing else',
      );
    });

    test('realtime events still arrive (the merge did not break the swap)',
        () async {
      final h = _harness();
      final seen = <ChatEvent>[];
      final sub = h.gateway.subscribe(_conversationId).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      h.realtimeLeg.emit(
        const RealtimeTransportChanged(live: true, reason: 'first_snapshot'),
      );
      await pumpEventQueue();

      expect(seen.single, isA<RealtimeTransportChanged>());
      expect((seen.single as RealtimeTransportChanged).live, isTrue);
    });

    test('each leg is opened exactly once, and only on first listen', () async {
      final h = _harness();
      final stream = h.gateway.subscribe(_conversationId);

      // Nothing is open yet. A channel nobody reads must not exist — on the
      expect(h.source.subscribeCalls, 0);
      expect(h.http.subscribeCalls, 0);

      final sub = stream.listen((_) {});
      addTearDown(sub.cancel);
      await pumpEventQueue();

      expect(h.source.subscribeCalls, 1);
      expect(h.http.subscribeCalls, 1);
      expect(h.realtimeLeg.listens, 1);
      expect(h.innerLeg.listens, 1);
    });
  });

  group('cancellation tears down BOTH legs', () {
    test('cancelling the merged subscription cancels realtime AND inner',
        () async {
      // The leak this guards is worse than the bug it accompanies: a merge that
      final h = _harness();
      final sub = h.gateway.subscribe(_conversationId).listen((_) {});
      await pumpEventQueue();

      expect(h.realtimeLeg.cancelled, isFalse);
      expect(h.innerLeg.cancelled, isFalse);

      await sub.cancel();
      await pumpEventQueue();

      expect(
        h.realtimeLeg.cancelled,
        isTrue,
        reason: 'the Firestore channel must close with the merged stream',
      );
      expect(
        h.innerLeg.cancelled,
        isTrue,
        reason: 'the inner leg is the one a naive merge forgets',
      );
    });

    test('a cancelled merge delivers nothing further from either leg',
        () async {
      final h = _harness();
      final seen = <ChatEvent>[];
      final sub = h.gateway.subscribe(_conversationId).listen(seen.add);
      await pumpEventQueue();
      await sub.cancel();

      h.realtimeLeg.emit(const RealtimeTransportChanged(live: true));
      h.innerLeg.emit(const PhaseChanged(ConversationPhase.accepted));
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });

  group('one dead leg does not silence the other', () {
    test('the phase channel survives the realtime channel closing', () async {
      // `RealtimeTransportChanged(live:false)` exists precisely to describe a
      final h = _harness();
      final seen = <ChatEvent>[];
      var closed = false;
      final sub = h.gateway
          .subscribe(_conversationId)
          .listen(seen.add, onDone: () => closed = true);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await h.realtimeLeg.close();
      await pumpEventQueue();
      expect(closed, isFalse, reason: 'one leg down is not the merge down');

      await h.gateway.acceptOffer(_conversationId, 'offer-1');
      await pumpEventQueue();

      expect(seen.whereType<PhaseChanged>(), hasLength(1));
    });

    test('the merged stream closes once EVERY leg is done', () async {
      final h = _harness();
      var closed = false;
      final sub = h.gateway
          .subscribe(_conversationId)
          .listen((_) {}, onDone: () => closed = true);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await h.realtimeLeg.close();
      await pumpEventQueue();
      expect(closed, isFalse);

      await h.innerLeg.close();
      await pumpEventQueue();
      expect(closed, isTrue);
    });
  });
}
