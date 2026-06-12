import 'dart:async';

import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';

/// Debug-only in-memory gateway that seeds a deterministic chat thread for one
/// of the designed client states so the screen can be captured on the
/// emulator without a live backend.
///
/// Selected via the `jeeb.state` dev-seam knob (formerly the `JEEB_DEV_CHAT`
/// dart-define):
///   - `sending`      → Figma node 56535:6469 (the single outgoing initial
///                      request, *before* any offer arrives — composer visible,
///                      no offer cards). [sending] true, [phase] broadcasting.
///   - `broadcasting` → Figma node 56535:6659 (the same request *plus* the
///                      stacked offer cards that have started landing).
///   - `accepted`     → Figma node 56546:2382 (1:1 accepted thread).
/// It extends the existing in-memory dev seam (pilot learning #2) and is wired
/// only behind a `kDebugMode` guard in [DevChatPreviewScreen], so it is inert
/// in release builds.
class DevChatFixtureGateway extends ChatGateway {
  DevChatFixtureGateway({
    required this.phase,
    this.deliveryMan = false,
    this.sending = false,
  });

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

  /// When true, [loadHistory] seeds the Jeeber-side delivery thread used by the
  /// chat states 04–07 (one incoming client request + one outgoing Jeeber
  /// offer) instead of the client-side accepted thread.
  final bool deliveryMan;

  /// When true, [loadHistory] seeds ONLY the client's single outgoing initial
  /// request (no offer cards) — the pre-offers "sending my initial request"
  /// frame (Figma 56535:6469). The [phase] stays [ConversationPhase.broadcasting]
  /// so the composer is visible and no counterpart header renders, exactly as
  /// the frame shows; the broadcasting offer-note footer is automatically
  /// suppressed because there are no offer cards in the list.
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

  /// Pre-offers "sending my initial request" thread (Figma 56535:6469): the
  /// single outgoing initial request bubble in the read state (teal double-tick),
  /// seeded at today 09:41, with NO offer cards. This is the same outgoing
  /// message [_broadcastingThread] opens with — the broadcasting state is this
  /// state plus the offer cards that arrive next (56535:6659).
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

  /// Jeeber-side thread for the delivery-man chat states (04–07). The client's
  /// request is the incoming bubble; the Jeeber's price/time offer is the
  /// outgoing bubble — mirrors Figma nodes 56539:906 / 56560:1605.
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
