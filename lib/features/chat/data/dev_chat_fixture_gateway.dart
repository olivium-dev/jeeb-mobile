import 'dart:async';

import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';

class DevChatFixtureGateway extends ChatGateway {
  DevChatFixtureGateway({
    required this.phase,
    this.deliveryMan = false,
    this.sending = false,
  });

  final ConversationPhase phase;

  final _controller = StreamController<ChatEvent>.broadcast();

  static final DateTime _at0941 = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 9, 41);
  }();

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async => phase;

  final bool deliveryMan;

  final bool sending;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    if (deliveryMan) return _deliveryManThread();
    if (sending) return _sendingThread();
    return phase == ConversationPhase.broadcasting
        ? _broadcastingThread()
        : _acceptedThread();
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.read);

  Future<void> dispose() => _controller.close();

  List<DeliveryChatMessage> _sendingThread() => [
        DeliveryChatMessage.text(
          id: 'dev-out-1',
          author: ChatAuthor.me,
          sentAt: _at0941,
          status: MessageStatus.read,
          text: 'I need 3 kilos of potatoes and water gallon and coffee '
              'from blend',
        ),
      ];

  List<DeliveryChatMessage> _broadcastingThread() => [
        DeliveryChatMessage.text(
          id: 'dev-out-1',
          author: ChatAuthor.me,
          sentAt: _at0941,
          status: MessageStatus.read,
          text: 'I need 3 kilos of potatoes and water gallon and coffee '
              'from blend',
        ),
        DeliveryChatMessage.offerCard(
          id: 'dev-offer-1',
          author: ChatAuthor.them,
          sentAt: _at0941,
          status: MessageStatus.delivered,
          payload: const OfferCardPayload(
            offerId: 'offer-kamal',
            jeeberId: 'jeeber-kamal',
            jeeberName: 'Kamal Hajj',
            rating: 4,
            ratingCount: 32,
            fee: 35,
            currency: 'USD',
            etaMinutes: 120,
            note: 'Hi i can bring you your order in 2 hours for  35\$',
          ),
        ),
        DeliveryChatMessage.offerCard(
          id: 'dev-offer-2',
          author: ChatAuthor.them,
          sentAt: _at0941,
          status: MessageStatus.delivered,
          payload: const OfferCardPayload(
            offerId: 'offer-rana',
            jeeberId: 'jeeber-rana',
            jeeberName: 'Rana Ahmad',
            rating: 4,
            ratingCount: 18,
            fee: 50,
            currency: 'USD',
            etaMinutes: 180,
            note: 'Hi i can bring you your order in 3 hours for  50\$',
          ),
        ),
      ];

  List<DeliveryChatMessage> _acceptedThread() => [
        DeliveryChatMessage.text(
          id: 'dev-a-out-1',
          author: ChatAuthor.me,
          sentAt: _at0941,
          status: MessageStatus.read,
          text: 'I need 3 kilos of potatoes and water gallon and coffee '
              'from blend',
        ),
        DeliveryChatMessage.text(
          id: 'dev-a-in-1',
          author: ChatAuthor.them,
          sentAt: _at0941,
          status: MessageStatus.delivered,
          text: 'Hi i can bring you your order in 3 hours for  20\$',
        ),
        DeliveryChatMessage.text(
          id: 'dev-a-out-2',
          author: ChatAuthor.me,
          sentAt: _at0941,
          status: MessageStatus.read,
          text: 'Hello Kamal please i need the water to be tanourine',
        ),
      ];

  List<DeliveryChatMessage> _deliveryManThread() => [
        DeliveryChatMessage.text(
          id: 'dev-dm-in-1',
          author: ChatAuthor.them,
          sentAt: _at0941,
          status: MessageStatus.delivered,
          text: 'I need 3 kilos of potatoes and water gallon and coffee '
              'from blend',
        ),
        DeliveryChatMessage.text(
          id: 'dev-dm-out-1',
          author: ChatAuthor.me,
          sentAt: _at0941,
          status: MessageStatus.read,
          text: 'Hi i can bring you your order in 3 hours for  20\$',
        ),
      ];
}

/// A gateway whose history read throws — the dev-seam and catalog failure
/// rung. Lives in the product tree so no product file imports lib/devtool/.
class FailingChatGateway extends ChatGateway {
  FailingChatGateway({this.error});

  /// What the read throws. Null is a server-side 500; pass a [NetworkFailure]
  /// to reach the connectivity rung, which a 500 must never claim.
  final Object? error;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    throw error ??
        StateError(
          'fixture: HTTP 500 from GET '
          '/v1/conversations/$conversationId/messages',
        );
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.failed);

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}
