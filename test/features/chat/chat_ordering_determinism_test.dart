import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// S0-CHAT-04 hardening — deterministic chronological ordering.
/// Two regressions are locked here:
///   1. Equal `sentAt` messages must sort by a SERVER-STABLE key (the message
class _OrderingGateway extends ChatGateway {
  _OrderingGateway({this.history = const <DeliveryChatMessage>[]});

  List<DeliveryChatMessage> history;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      List<DeliveryChatMessage>.from(history);

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  @override
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async =>
      const OfferAcceptResult(deliveryId: 'd-accepted');

  void push(ChatEvent event) => _controller.add(event);
  Future<void> dispose() => _controller.close();
}

DeliveryChatMessage _them(String id, DateTime at, String text) =>
    DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.them,
      sentAt: at,
      status: MessageStatus.delivered,
      text: text,
    );

ChatCubit _build(_OrderingGateway gw) {
  final cubit = ChatCubit(
    deliveryId: 'd1',
    gateway: gw,
    pickerService: StubPhotoPickerService(),
  );
  addTearDown(cubit.close);
  addTearDown(gw.dispose);
  return cubit;
}

void main() {
  group('S0-CHAT-04 — equal-timestamp messages sort by stable id', () {
    // Same instant, ids out of order in the backing list. The sort must put
    final tie = DateTime.utc(2026, 5, 17, 10, 30);

    test('cold-load history with an equal-`sentAt` pair sorts by id', () async {
      final gw = _OrderingGateway(history: [
        _them('m-b', tie, 'second'),
        _them('m-a', tie, 'first'),
      ]);
      final cubit = _build(gw);
      await cubit.load();
      expect(
        cubit.state.messages.map((m) => m.id).toList(),
        ['m-a', 'm-b'],
        reason: 'equal sentAt → ascending id, not backing-list position',
      );
    });

    test(
      'WS arrival order does NOT change the final order of an equal-`sentAt` '
      'pair (matches the reloaded order)',
      () async {
        // Arrive b THEN a over the live stream; final order must still be a,b.
        final gw = _OrderingGateway();
        final cubit = _build(gw);
        await cubit.load();
        gw.push(IncomingMessage(_them('m-b', tie, 'second')));
        gw.push(IncomingMessage(_them('m-a', tie, 'first')));
        await Future<void>.delayed(Duration.zero);
        expect(
          cubit.state.messages.map((m) => m.id).toList(),
          ['m-a', 'm-b'],
          reason: 'arrival path must not leak into the rendered order',
        );
      },
    );
  });

  group('S0-CHAT-04 — acceptOffer re-fetch is sorted', () {
    test('history returned by the accept re-fetch is ordered by server time',
        () async {
      // Backend returns rows newest-first (unsorted relative to the timeline).
      final gw = _OrderingGateway(history: [
        _them('m3', DateTime.utc(2026, 5, 17, 10, 32), 'newest'),
        _them('m1', DateTime.utc(2026, 5, 17, 10, 30), 'oldest'),
        _them('m2', DateTime.utc(2026, 5, 17, 10, 31), 'middle'),
      ]);
      final cubit = _build(gw);
      await cubit.acceptOffer('offer-1');
      expect(
        cubit.state.messages.map((m) => m.id).toList(),
        ['m1', 'm2', 'm3'],
        reason: 'acceptOffer must apply the same chronological sort as load()',
      );
    });
  });
}
