import 'dart:async';

import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';

/// MVP gateway with no backend.
///
/// `send` succeeds after a short artificial delay (so the optimistic
/// `sending → sent → delivered → read` transitions are observable in the
/// UI). It also emits a canned echo from the counterpart on the
/// [subscribe] stream so the conversation feels two-sided in demo builds
/// and in widget tests that want to exercise the receiver path.
///
/// Tests inject their own gateway via the cubit's constructor.
class InMemoryChatGateway extends ChatGateway {
  InMemoryChatGateway({
    this.sendDelay = const Duration(milliseconds: 80),
    this.deliveryDelay = const Duration(milliseconds: 160),
    this.readDelay = const Duration(milliseconds: 320),
    this.echoDelay = const Duration(milliseconds: 480),
    this.echoEnabled = true,
  });

  /// Latency before [send] resolves with [MessageStatus.sent]. Kept small so
  /// the UI flow feels responsive while still exercising the optimistic path.
  final Duration sendDelay;

  /// Additional latency before the gateway emits a delivered receipt for the
  /// most-recently-sent message.
  final Duration deliveryDelay;

  /// Additional latency before the gateway emits a read receipt.
  final Duration readDelay;

  /// Latency before the canned echo arrives from the counterpart.
  final Duration echoDelay;

  /// When false, the gateway only handles sends — no inbound echo. Tests use
  /// this when asserting outgoing behaviour without racing the receiver path.
  final bool echoEnabled;

  final _controller = StreamController<ChatEvent>.broadcast();

  int _replyCounter = 0;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String deliveryId) async {
    // No persistence in the MVP — the cubit starts each session with an empty
    // thread, exactly like a freshly created delivery.
    return const <DeliveryChatMessage>[];
  }

  @override
  Future<DeliveryChatMessage> send(
    String deliveryId,
    DeliveryChatMessage message,
  ) async {
    await Future<void>.delayed(sendDelay);
    final sent = message.copyWith(status: MessageStatus.sent);
    // Schedule the delivered / read transitions independently so the
    // double-tick render happens after the single-tick.
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
