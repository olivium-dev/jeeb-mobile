import 'dart:async';

import 'package:dio/dio.dart';

import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import '../domain/chat_gateway.dart';
import '../domain/chat_socket.dart';
import '../domain/delivery_chat_message.dart';
import 'chat_realtime_resolver.dart';

/// Dio + Phoenix-channel backed [ChatGateway], speaking the CANONICAL Jeeb
/// conversation contract.
///
/// CHAT-CONTRACT (iter6 — canonical rewrite): the gateway is constructed with a
/// REAL server-minted **conversation_id** (resolved by [ChatDetailScreen] via
/// `POST /v1/chat/jeeb/conversations` create-or-get BEFORE any messaging) — it
/// NO LONGER receives a request id and NO LONGER tries the non-existent
/// `by-request` route. Every `loadHistory`/`send`/`subscribe` call therefore
/// uses the conversation id directly on the canonical paths:
///
/// HTTP side:
///   GET  /v1/conversations/{conversationId}/messages   → per-viewer history
///   POST /v1/conversations/{conversationId}/messages   → send (author from bearer)
///   POST /v1/offers/{offerId}/accept                   → acceptOffer
///
/// WebSocket side:
///   Resolves the PER-CONVERSATION realtime descriptor from the gateway
///   (`GET /v1/realtime/jeeb:chat:{conversationId}` → topic + ticket via
///   [ChatRealtimeResolver]) and joins THAT topic with the gateway-minted
///   ticket. Inbound `new_msg` frames append to the open thread live. On any
///   resolve/connect failure the thread degrades to HTTP-history only.
///
/// The gateway is conversation-scoped: each instance owns one socket and
/// expects every call to use the same conversation id. The cubit creates a
/// fresh instance per chat thread.
class DioChatGateway implements ChatGateway {
  DioChatGateway({
    required Dio dio,
    required this.currentUserId,
    ChatRealtimeResolver? realtimeResolver,
    ChatSocket Function(String conversationId)? socketFactory,
  })  : _dio = dio,
        _realtimeResolver = realtimeResolver ??
            ChatRealtimeResolver(dio: dio, currentUserId: currentUserId),
        _socketFactory = socketFactory;

  final Dio _dio;

  /// Id of the local user. Used to derive [ChatAuthor.me] vs `them` when
  /// folding inbound/historical messages. author_id on a posted message is
  /// stamped SERVER-SIDE from the bearer — never sent in the body.
  final String currentUserId;

  final ChatRealtimeResolver _realtimeResolver;
  final ChatSocket Function(String conversationId)? _socketFactory;

  ChatSocket? _socket;
  bool _socketRequested = false;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    // CANONICAL list: per-viewer, server-side filtered (the viewer is the
    // bearer sub — the gateway forwards it; we do NOT client-filter). The
    // response shape is `{messages: [{message_id, author_id, body, kind,
    // created_at, ...}]}`.
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/chat/jeeb/conversations/$conversationId/messages',
    );
    final data = response.data;
    if (data == null) return const <DeliveryChatMessage>[];
    final items = data['items'] ?? data['messages'];
    if (items is! List) return const <DeliveryChatMessage>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .toList(growable: false);
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    // The conversation phase is resolved up front at [ChatDetailScreen] (from
    // the create-or-get response). The per-message list route carries no phase,
    // so the gateway-level fetch is a no-op that keeps the cubit's first paint
    // unchanged (`accepted` preserves the existing 1:1 behaviour); the screen
    // already threads the authoritative phase into the UI.
    return ConversationPhase.accepted;
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async {
    // CANONICAL fan-out append (iter6 route fix): POST to
    // `/v1/chat/jeeb/conversations/{id}/messages` — the JeebChatMessagesController
    // BFF that PERSISTS to chat-service AND fans the message out live over
    // realtime (`:5804`) to the counterpart. The prior `/v1/conversations/{id}/
    // messages` route (JeebConversationsController) only persisted — no live
    // push — so the counterpart never received the message without a reload.
    //
    // WIRE SHAPE: the fan-out BFF (`MobileSendMessageBody`) expects a NESTED
    // `body` object (`{text}` / `{url,caption}` / `{lat,lng,label}` / ...), NOT a
    // flat string. The gateway JSON-encodes that nested object into chat-service's
    // flat body string and decodes it back on read/fan-out, so live == reload.
    // author_id is stamped from the bearer server-side — we DROP any senderId.
    final data = <String, Object?>{
      'kind': message.kind.wireName,
      'body': _nestedBodyFor(message),
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/chat/jeeb/conversations/$conversationId/messages',
      data: data,
      options: Options(
        headers: <String, Object?>{
          'Idempotency-Key': message.id,
        },
      ),
    );
    final ack = response.data;
    final serverId = (ack?['id'] ?? ack?['message_id']) as String?;
    // Once the server acknowledges, the message is at-least `sent`. The
    // delivered/read receipts arrive over the socket later.
    return message.copyWith(status: MessageStatus.sent).._serverIdProbe(serverId);
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    _ensureSocket(conversationId);
    return _events.stream;
  }

  /// The network gateway's live transport is the realtime WebSocket, which may
  /// never establish against the mock backend (no live push), or for a
  /// non-member / flaky socket. So the cubit also runs an HTTP-history poll
  /// fallback — inbound still works ("live == within one poll").
  @override
  bool get supportsPolling => true;

  @override
  Future<OfferAcceptResult> acceptOffer(
    String conversationId,
    String offerId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/offers/$offerId/accept',
      data: <String, Object?>{
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
        'acceptedBy': currentUserId,
      },
      options: Options(
        headers: <String, Object?>{
          'Idempotency-Key': 'accept-$offerId',
        },
      ),
    );
    final deliveryId = _deliveryIdOf(response.data);
    if (!_events.isClosed) {
      _events.add(
        PhaseChanged(ConversationPhase.accepted, deliveryId: deliveryId),
      );
    }
    return OfferAcceptResult(deliveryId: deliveryId);
  }

  /// Defensive read of the server-created delivery id from the accept body.
  String? _deliveryIdOf(Map<String, dynamic>? body) {
    if (body == null) return null;
    final raw = body['deliveryId'] ?? body['delivery_id'];
    return raw is String && raw.trim().isNotEmpty ? raw : null;
  }

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async {
    final form = FormData.fromMap({
      'durationMs': durationMs,
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: 'voice-note.m4a',
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/voice/transcribe',
      data: form,
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final body = response.data ?? const <String, dynamic>{};
    return VoiceUploadResult(
      url: body['url'] as String? ?? body['audioUrl'] as String? ?? '',
      transcription: body['transcript'] as String? ??
          body['transcription'] as String?,
    );
  }

  Future<void> dispose() async {
    await _socket?.close();
    if (!_events.isClosed) await _events.close();
  }

  // ---------------------------------------------------------------------------
  // Socket plumbing (per-conversation topic + gateway ticket)
  // ---------------------------------------------------------------------------

  void _ensureSocket(String conversationId) {
    if (_socketRequested) return;
    _socketRequested = true;
    unawaited(_connectAndJoin(conversationId));
  }

  /// CHAT-CONTRACT (iter6): join the PER-CONVERSATION realtime topic with the
  /// gateway-minted ticket. The [ChatRealtimeResolver] runs the gateway
  /// membership pre-check (`/v1/realtime/jeeb:chat:{id}`) and builds a socket
  /// bound to the descriptor's topic + ticket. On any failure (non-member 403,
  /// flag-off 503, transport, connect) the socket is null/throws and the thread
  /// degrades to HTTP-history only — exactly the prior degrade-don't-fail
  /// behaviour, never a hard failure.
  Future<void> _connectAndJoin(String conversationId) async {
    try {
      final socket = _socketFactory?.call(conversationId) ??
          await _realtimeResolver.connect(conversationId);
      if (socket == null) return; // not a member / flag off → HTTP history only
      _socket = socket;
      await socket.connect();
      // Trigger the Phoenix v2 join on the resolved per-conversation topic.
      socket.send(<String, Object?>{'event': 'phx_join'});
      socket.events.listen(_handleFrame);
    } catch (_) {
      // Soft failure — the cubit still has HTTP history; no live push.
    }
  }

  void _handleFrame(Map<String, Object?> frame) {
    if (_events.isClosed) return;
    final event = frame['event'] as String?;
    if (event != 'new_msg') return;
    final payload = frame['payload'];
    if (payload is! Map) return;
    try {
      final message = _parseMessage(payload.cast<String, dynamic>());
      _events.add(IncomingMessage(message));
    } catch (_) {
      // Ignore malformed frames — keep the subscription alive.
    }
  }

  // ---------------------------------------------------------------------------
  // Wire ↔ domain mapping
  // ---------------------------------------------------------------------------

  /// Build the NESTED `body` object the canonical fan-out send route
  /// (`POST /v1/chat/jeeb/conversations/{id}/messages` → `MobileSendMessageBody`)
  /// expects. The gateway JSON-encodes this object verbatim into chat-service's
  /// flat body string and decodes it back on read/fan-out, so the keys here are
  /// exactly the ones the read/normalize paths consume (`text` / `url` /
  /// `caption` / `durationMs` / `lat` / `lng` / `label`) — guaranteeing the live
  /// fan-out bubble and the reloaded bubble render identically.
  Map<String, Object?> _nestedBodyFor(DeliveryChatMessage message) {
    switch (message.kind) {
      case MessageKind.text:
        return <String, Object?>{'text': message.text};
      case MessageKind.image:
        return <String, Object?>{
          'url': message.imageUrl ?? '',
          if (message.text.isNotEmpty) 'caption': message.text,
        };
      case MessageKind.voice:
        return <String, Object?>{
          'url': message.voiceUrl ?? '',
          'durationMs': message.voiceDurationMs ?? 0,
        };
      case MessageKind.location:
        return <String, Object?>{
          'lat': message.latitude ?? 0,
          'lng': message.longitude ?? 0,
          if (message.text.isNotEmpty) 'label': message.text,
        };
      case MessageKind.photo:
        return <String, Object?>{
          if (message.text.isNotEmpty) 'caption': message.text,
        };
      case MessageKind.system:
      case MessageKind.offerCard:
      case MessageKind.offerAccepted:
      case MessageKind.offerRejected:
        // Server-emitted; the client doesn't post them — but if one is ever
        // dispatched, carry its text so it still renders.
        return <String, Object?>{'text': message.text};
    }
  }

  DeliveryChatMessage _parseMessage(Map<String, dynamic> json) {
    // CANONICAL message: {message_id, author_id, kind, subtype, body, payload,
    // created_at}. Accept the legacy {id, senderId, createdAt} too so a frame
    // already normalized by the socket and a raw chat-service row both parse.
    final id = (json['message_id'] ?? json['id']) as String? ?? '';
    final senderId =
        (json['author_id'] ?? json['senderId'] ?? json['sender_id']) as String? ??
            '';
    final author = senderId == currentUserId ? ChatAuthor.me : ChatAuthor.them;
    final sentAt = DateTime.tryParse(
                (json['created_at'] ?? json['createdAt']) as String? ?? '')
            ?.toLocal() ??
        DateTime.now();
    final kind =
        MessageKind.fromWire((json['kind'] ?? json['subtype']) as String?);
    // `body` is a free-text string on the canonical text wire; structured kinds
    // carry their shape in `payload`. Fold both onto the {text|...} map the
    // bubble builder consumes.
    final rawBody = json['body'];
    final rawPayload = json['payload'];
    final Map<String, Object?> body;
    if (rawBody is Map) {
      body = rawBody.cast<String, Object?>();
    } else if (rawPayload is Map) {
      body = rawPayload.cast<String, Object?>();
    } else if (rawBody is String) {
      body = <String, Object?>{'text': rawBody};
    } else {
      body = const <String, Object?>{};
    }
    return _buildMessage(
      id: id,
      author: author,
      sentAt: sentAt,
      kind: kind,
      body: body,
    );
  }

  DeliveryChatMessage _buildMessage({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageKind kind,
    required Map<String, Object?> body,
  }) {
    const status = MessageStatus.delivered;
    switch (kind) {
      case MessageKind.text:
        return DeliveryChatMessage.text(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          text: body['text'] as String? ?? '',
        );
      case MessageKind.image:
        return DeliveryChatMessage.image(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          url: body['url'] as String? ?? '',
          caption: body['caption'] as String? ?? '',
        );
      case MessageKind.voice:
        return DeliveryChatMessage.voice(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          url: body['url'] as String? ?? '',
          durationMs: body['durationMs'] as int? ?? 0,
        );
      case MessageKind.location:
        final lat = body['lat'];
        final lng = body['lng'];
        return DeliveryChatMessage.location(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          lat: lat is num ? lat.toDouble() : 0,
          lng: lng is num ? lng.toDouble() : 0,
          label: body['label'] as String? ?? '',
        );
      case MessageKind.system:
        return DeliveryChatMessage.system(
          id: id,
          sentAt: sentAt,
          text: body['text'] as String? ?? '',
        );
      case MessageKind.offerCard:
        return DeliveryChatMessage.offerCard(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          payload: OfferCardPayload.fromWire(body),
        );
      case MessageKind.offerAccepted:
        return DeliveryChatMessage.offerAccepted(
          id: id,
          sentAt: sentAt,
          payload: SystemOfferPayload.fromWire(body),
        );
      case MessageKind.offerRejected:
        return DeliveryChatMessage.offerRejected(
          id: id,
          sentAt: sentAt,
          payload: SystemOfferPayload.fromWire(body),
        );
      case MessageKind.photo:
        return DeliveryChatMessage.text(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          text: body['caption'] as String? ?? body['text'] as String? ?? '',
        );
    }
  }
}

/// Extension hook — `_serverIdProbe` is a no-op today because
/// [DeliveryChatMessage] hashes by `id` (the client id). When the message
/// model grows a `serverId`, this is the swap point.
extension on DeliveryChatMessage {
  void _serverIdProbe(String? _) {}
}
