import 'dart:async';

import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';

class InMemoryChatGateway extends ChatGateway {
  InMemoryChatGateway({
    this.sendDelay = const Duration(milliseconds: 80),
    this.deliveryDelay = const Duration(milliseconds: 160),
    this.readDelay = const Duration(milliseconds: 320),
    this.echoDelay = const Duration(milliseconds: 480),
    this.echoEnabled = true,
  });

  final Duration sendDelay;

  final Duration deliveryDelay;

  final Duration readDelay;

  final Duration echoDelay;

  final bool echoEnabled;

  final _controller = StreamController<ChatEvent>.broadcast();

  int _replyCounter = 0;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String deliveryId) async {
    return const <DeliveryChatMessage>[];
  }

  @override
  Future<ConversationPhase> loadPhase(String deliveryId) async =>
      ConversationPhase.accepted;

  @override
  Future<DeliveryChatMessage> send(
    String deliveryId,
    DeliveryChatMessage message,
  ) async {
    await Future<void>.delayed(sendDelay);
    final sent = message.copyWith(status: MessageStatus.sent);
    Future<void>.delayed(deliveryDelay, () {
      if (_controller.isClosed) return;
      _controller.add(DeliveryReceipt(message.id));
    });
    Future<void>.delayed(deliveryDelay + readDelay, () {
      if (_controller.isClosed) return;
      _controller.add(ReadReceipt(message.id));
    });
    if (echoEnabled) {
      Future<void>.delayed(deliveryDelay + echoDelay, () {
        if (_controller.isClosed) return;
        final reply = DeliveryChatMessage.text(
          id: 'echo-${_replyCounter++}',
          author: ChatAuthor.them,
          sentAt: DateTime.now(),
          status: MessageStatus.delivered,
          text: _replyFor(message),
        );
        _controller.add(IncomingMessage(reply));
      });
    }
    return sent;
  }

  @override
  Stream<ChatEvent> subscribe(String deliveryId) => _controller.stream;

  Future<void> dispose() => _controller.close();

  String _replyFor(DeliveryChatMessage message) {
    if (message.isPhoto) return 'Got the photo, thanks!';
    return 'Got it — on my way.';
  }
}
