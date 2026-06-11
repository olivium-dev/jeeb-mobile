import 'dart:async';

import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';

/// Debug-only in-memory gateway that seeds a deterministic chat thread for one
/// of the two designed client states so the screen can be captured on the
/// emulator without a live backend.
///
/// Selected via the `JEEB_DEV_CHAT` dart-define (`broadcasting` → Figma node
/// 56535:6659, `accepted` → node 56546:2382). It extends the existing
/// in-memory dev seam (pilot learning #2) and is wired only behind a
/// `kDebugMode` guard in [ChatTab], so it is inert in release builds.
class DevChatFixtureGateway extends ChatGateway {
  DevChatFixtureGateway({required this.phase});

  /// The conversation phase this fixture renders.
  final ConversationPhase phase;

  final _controller = StreamController<ChatEvent>.broadcast();

  /// Today at 09:41 so the date separator reads "Today" (Figma parity) while
  /// the per-message timestamps stay fixed for deterministic capture.
  static final DateTime _at0941 = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 9, 41);
  }();

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async => phase;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
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
}
