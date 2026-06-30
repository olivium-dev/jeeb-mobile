import 'dart:async';

import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import 'delivery_chat_message.dart';

/// Route/id sentinel used by the order-compose flow BEFORE a real
/// request/conversation exists. The client pushes `chat-detail` with this
/// literal id (`client_location_screen.dart`), and the compose coordinator
/// replaces it with the SERVER-MINTED request id on first send.
///
/// It is NOT a valid backend conversation id: there is no
/// `/v1/conversations/new...` route on the gateway (trace doc §4 — grep of
/// every gateway route attribute for the segment `new` → zero matches), and a
/// fresh request has no conversation at all until a Jeeber accepts (the
/// conversation is provisioned post-accept). Therefore any id-scoped chat HTTP
/// call MUST short-circuit on this sentinel rather than emit a guaranteed-404
/// request to `/v1/conversations/new/messages`.
///
/// Canonical home so the gateway (data layer) and the coordinator (application
/// layer) share one source of truth — see
/// `OrderComposeCoordinator.composeSentinel`, which aliases this.
const String kComposeConversationSentinel = 'new';

/// Outbound contract for chat transport. The cubit handles optimistic UI
/// (every outgoing message lands as [MessageStatus.sending] immediately and
/// then transitions on the gateway's acknowledgement), so the gateway only
/// owns the network/round-trip — never the in-memory list.
///
/// The MVP build wires this to [InMemoryChatGateway] which echoes a single
/// canned reply per outgoing message so the chat screen can be demoed end to
/// end without any real backend. The Dio-backed [DioChatGateway] points the
/// same interface at the mock backend (or, in prod, `jeeb-gateway`) via the
/// chat-service + offer-service routes.
///
/// The first positional argument is named [conversationId] in the new chat
/// flow; it stays compatible with the older photo-chat call sites that pass
/// a delivery id because both ids are opaque strings to the gateway.
abstract class ChatGateway {
  /// History of messages previously exchanged on this thread. Returned newest
  /// last so the cubit can append without sorting.
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId);

  /// Conversation phase ([ConversationPhase.broadcasting] / `accepted` /
  /// `closed`) the cubit needs to render the right UI shell (composer on/off,
  /// offer-card list vs 1:1 timeline). Optional — gateways that don't carry
  /// a phase (the MVP in-memory echo) can return [ConversationPhase.accepted]
  /// to retain the existing 1:1 behaviour.
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.accepted;

  /// Push an outgoing message. Returns the same message with its status
  /// promoted to at-least [MessageStatus.sent]; the caller swaps the optimistic
  /// entry for this one. Throwing surfaces as [MessageStatus.failed] on the
  /// optimistic entry.
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  );

  /// Stream of inbound events for this thread — incoming messages from the
  /// counterpart, delivered receipts, read receipts, and (post-accept) phase
  /// transitions.
  Stream<ChatEvent> subscribe(String conversationId);

  /// Accept a Jeeber's offer from inside the broadcasting chat. Drives the
  /// offer-service saga (winning offer accepted, losers superseded, phase
  /// flipped, system message appended). The gateway is responsible for the
  /// HTTP call; the cubit re-fetches history + phase once this resolves.
  ///
  /// Returns an [OfferAcceptResult] carrying the server-created
  /// [OfferAcceptResult.deliveryId] so the cubit can offer a "Track order"
  /// path into live tracking. The default (MVP in-memory + dev-fixture
  /// gateways) returns [OfferAcceptResult.empty] — no delivery id — which the
  /// cubit treats as "tracking not yet reachable".
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async =>
      OfferAcceptResult.empty;

  /// Upload a raw voice clip to `/v1/voice/transcribe` and return the CDN URL
  /// and optional transcription text. The [idempotencyKey] must be stable
  /// across retries so the voice-transcription-service deduplicates uploads.
  /// Returns a [VoiceUploadResult] — callers store the URL in the voice bubble
  /// and optionally fill the transcription text when it arrives.
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async => const VoiceUploadResult(url: '', transcription: null);
}

/// Result returned by [ChatGateway.uploadVoice].
class VoiceUploadResult {
  const VoiceUploadResult({required this.url, this.transcription});

  /// CDN URL of the uploaded audio file.
  final String url;

  /// AI-generated transcription text. Null when the transcription has not
  /// resolved yet (async path) or when the backend timed out.
  final String? transcription;
}

/// Closed union of inbound chat events. Kept as a sealed-style hierarchy so
/// the cubit can `switch` on the runtime type without needing a discriminator
/// field.
sealed class ChatEvent {
  const ChatEvent();
}

/// A new message arrived from the counterpart.
class IncomingMessage extends ChatEvent {
  const IncomingMessage(this.message);
  final DeliveryChatMessage message;
}

/// The counterpart's device confirmed delivery for [messageId].
/// Promotes its status from [MessageStatus.sent] to [MessageStatus.delivered].
class DeliveryReceipt extends ChatEvent {
  const DeliveryReceipt(this.messageId);
  final String messageId;
}

/// The counterpart's device acknowledged read for everything up to and
/// including [throughMessageId]. The cubit walks back through its outgoing
/// queue and promotes anything still in [MessageStatus.sent]/[delivered].
class ReadReceipt extends ChatEvent {
  const ReadReceipt(this.throughMessageId);
  final String throughMessageId;
}

/// The conversation flipped phase (e.g. `broadcasting → accepted` after the
/// client accepted an offer). The cubit re-derives composer visibility and
/// re-fetches history so the system message is visible.
///
/// When the transition is the accept that created a delivery, [deliveryId]
/// carries the server-created delivery id so the cubit can expose the
/// "Track order" path even if it learns about the accept over the event
/// stream rather than from the [ChatGateway.acceptOffer] return value. Null
/// for any other phase transition (or when the gateway does not surface one).
class PhaseChanged extends ChatEvent {
  const PhaseChanged(this.phase, {this.deliveryId});
  final ConversationPhase phase;
  final String? deliveryId;
}
