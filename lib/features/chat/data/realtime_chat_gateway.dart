import 'dart:async';
import 'dart:typed_data';

import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import '../domain/delivery_chat_message.dart';

/// Replaces ONE method of a [ChatGateway] — [subscribe] — with a realtime
/// [ChatRealtimeSource], and forwards everything else untouched.
///
/// # Why a decorator rather than an edit to `DioChatGateway`
///
/// The split is the architecture, not a style choice. The owner's ruling is
/// *"the backend should only store in firestore… the mobile should subscribe"*,
/// and that maps exactly onto these two halves:
///
///   * **WRITES and one-shot READS stay HTTP.** `send` must keep going through
///     `POST /v1/conversations/{id}/messages`, because the gateway is what
///     stamps `author_id` from the bearer JWT (a client that wrote to Firestore
///     directly could post as anyone), what enforces idempotency, and what runs
///     the offer/accept saga. The cold `loadHistory` stays HTTP too: it is the
///     one read that must return the WHOLE thread, and it comes back already
///     filtered by `MessageVisibilityResolver`.
///   * **The live channel becomes Firestore.** Only the inbound stream changes.
///
/// Keeping that in a decorator means `DioChatGateway` is not conditionally two
/// different things depending on a flag, and a host with no realtime source
/// simply does not build this wrapper.
///
/// # It does not fall back
///
/// If the realtime source cannot open a channel this gateway does NOT quietly
/// substitute the old WebSocket stream. It forwards the source's
/// [RealtimeTransportChanged] `live: false` and lets `ChatCubit` decide — which
/// it does by keeping the HTTP fallback armed. A transport that silently
/// substitutes another transport is how a surface ends up with two live paths
/// and no way to tell which one is carrying it.
class RealtimeChatGateway implements ChatGateway {
  RealtimeChatGateway({
    required ChatGateway inner,
    required ChatRealtimeSource realtime,
  })  : _inner = inner,
        _realtime = realtime;

  final ChatGateway _inner;
  final ChatRealtimeSource _realtime;

  /// THE change. Everything below this method is forwarding.
  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      _realtime.subscribe(conversationId);

  /// Still true, and still for the same reason — but read the field's doc on
  /// [ChatGateway]. It no longer gates a poll: it gates the cold-load-failure
  /// retry, which is armed only in an error state and terminates on the first
  /// success. A realtime channel does not make a failed COLD load recover on its
  /// own (there is nothing on screen to push to), so this stays on.
  @override
  bool get supportsPolling => _inner.supportsPolling;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) =>
      _inner.loadHistory(conversationId);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) =>
      _inner.loadPhase(conversationId);

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) =>
      _inner.send(conversationId, message);

  @override
  Future<OfferAcceptResult> acceptOffer(String conversationId, String offerId) =>
      _inner.acceptOffer(conversationId, offerId);

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) =>
      _inner.uploadVoice(
        idempotencyKey: idempotencyKey,
        audioBytes: audioBytes,
        mimeType: mimeType,
        durationMs: durationMs,
      );

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      _inner.uploadImage(bytes: bytes, contentType: contentType);

  @override
  Future<Uint8List> fetchImageBytes(String objectRef) =>
      _inner.fetchImageBytes(objectRef);

  Future<void> dispose() => _realtime.dispose();
}
