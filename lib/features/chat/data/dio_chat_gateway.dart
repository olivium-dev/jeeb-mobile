import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import '../../otp_handover/domain/handover_code_store.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_socket.dart';
import '../domain/delivery_chat_message.dart';
import 'web_socket_chat_socket.dart';

/// Dio + Phoenix-channel backed [ChatGateway].
///
/// HTTP side — paths aligned to the routes the gateway actually mounts
/// (`jeeb-gateway` `JeebConversationsController`, cited in
/// `docs/sprints/sprint-006/order-create-trace.md` §3 & §6):
///   GET  /v1/conversations?correlationKey={id}          → conversation row
///                                                          (`[HttpGet("v1/conversations")]`,
///                                                          `GetConversationByCorrelation`,
///                                                          correlationKey == request_id) → loadPhase
///   GET  /v1/conversations/{id}/messages                → history (loadHistory)
///                                                          (`[HttpGet("v1/conversations/{conversationId}/messages")]`)
///   POST /v1/conversations/{id}/messages                → send
///                                                          (`[HttpPost("v1/conversations/{conversationId}/messages")]`)
///   POST /v1/offers/{offerId}/accept                    → acceptOffer (JeebOffersController)
///
/// HISTORICAL BUG (fixed here): these three id-scoped calls previously targeted
/// the `/v1/chat/jeeb/conversations/{id}[/messages]` prefix, which the gateway
/// mounts ONLY for conversation *create* (`[HttpPost("v1/chat/jeeb/conversations")]`),
/// not for messages or per-conversation reads. The same bogus id returned 404
/// at `/v1/chat/jeeb/conversations/{id}/messages` but 400 at
/// `/v1/conversations/{id}/messages` — i.e. the latter route exists and parses
/// the id (trace doc §5.2 / §6). Every in-thread message was therefore dropped.
///
/// WebSocket side:
///   Joins topic `jeeb:chat:{conversationId}` on
///   ws://…/realtime-comunication-service/socket/websocket and forwards every
///   inbound `new_msg` frame as an [IncomingMessage].
///
/// The gateway is conversation-scoped: each instance owns one socket and
/// expects every `loadHistory`/`send`/`subscribe` call to use the same
/// conversation id. The cubit creates a fresh instance per chat thread.
class DioChatGateway implements ChatGateway {
  DioChatGateway({
    required Dio dio,
    required this.currentUserId,
    String? conversationCorrelationKey,
    ChatSocket Function(String conversationId)? socketFactory,
    Uri? socketBaseUri,
    HandoverCodeStore? handoverCodeStore,
  })  : _dio = dio,
        _correlationKey = conversationCorrelationKey,
        _socketBaseUri = socketBaseUri ??
            Uri.parse(MockGatewayClient.webSocketUrl),
        _socketFactory = socketFactory,
        _handoverCodeStore = handoverCodeStore;

  final Dio _dio;

  /// G4: sink for the accept response's `handoverCode` (see
  /// [HandoverCodeStore]). The chat "Accept" CTA is the second accept path
  /// (besides the offer-review sheet) — it must retain + persist the code the
  /// same way. Null in tests that don't exercise persistence.
  final HandoverCodeStore? _handoverCodeStore;

  /// Id of the local user. Used to derive [ChatAuthor.me] vs `them` when
  /// folding inbound messages and to mark outgoing messages with the right
  /// `senderId`. The auth interceptor would normally inject this server-side;
  /// the mock just trusts whatever the client sends.
  final String currentUserId;

  /// The conversation's correlation key (== request id) used to read the
  /// conversation aggregate in [loadPhase]. The chat-service exposes the
  /// conversation ONLY by its correlation key
  /// (`GET /v1/conversations?correlationKey={requestId}`) — NEVER by the
  /// conversation id — so a phase read that posts the CONVERSATION id as the
  /// `correlationKey` 404s (`chat-service rejected the read conversation by
  /// correlation`, physical-run8 [Med] chat READ 404 #2). When the host resolved
  /// the request/correlation id it passes it here so the phase poll hits
  /// `?correlationKey={requestId}` (200). When null (tests / callers that only
  /// know the conversation id) [loadPhase] falls back to the id argument,
  /// preserving the prior behavior.
  final String? _correlationKey;

  final Uri _socketBaseUri;
  final ChatSocket Function(String conversationId)? _socketFactory;

  /// Stable per-gateway-instance sender scope used ONLY when [currentUserId] is
  /// empty (unauthenticated degrade). Minted once per chat-thread gateway so
  /// retries of the same message within the session keep a stable
  /// (idempotent) key, while still differing from the peer's client — the
  /// authenticated path uses the real user id and never touches this.
  late final String _fallbackSenderScope = _mintFallbackSenderScope();

  ChatSocket? _socket;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    // No conversation exists yet for the compose sentinel / empty id — a fresh
    // request has no conversation until a Jeeber accepts. Skip the guaranteed
    // 404 round-trip to `/v1/conversations/new/messages` (trace doc §5.1).
    if (_isUnresolvedConversation(conversationId)) {
      return const <DeliveryChatMessage>[];
    }
    final response = await _dio.get<dynamic>(
      '/v1/conversations/$conversationId/messages',
    );
    final data = response.data;
    // Tolerate every envelope the gateway/mock can emit: a bare array, or a
    // `{ items | messages | data: [...] }` wrapper.
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = (data['items'] as List?) ??
          (data['messages'] as List?) ??
          (data['data'] as List?) ??
          const <dynamic>[];
    } else {
      items = const <dynamic>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .toList(growable: false);
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    // A fresh request (compose sentinel / empty id) has no conversation row to
    // read — it is, by definition, still broadcasting. Return that directly
    // instead of issuing a 404 GET.
    if (_isUnresolvedConversation(conversationId)) {
      return ConversationPhase.broadcasting;
    }
    // NEW-BUG-01 (Sprint-2 Contract 5c) — RESTORED after the sprint-006/007
    // merge (bd86ab3) regressed this file to the un-hardened pre-fix loadPhase.
    // The gateway reads a conversation by its correlation key (== request id,
    // auto-conversation-per-request) via `GET /v1/conversations`; there is no
    // per-id `GET /v1/conversations/{id}` route. The response
    // (`JeebConversationResponse`) carries `phase` + `participants`.
    //
    // GATING (Contract 5c item 3): only surface `accepted` when the wire phase
    // is `accepted` AND an active `jeeber_winner` participant is seated. A phase
    // that claims `accepted` with no winner (mid-advance / partial saga)
    // degrades to `broadcasting` — never a false "Offer accepted!". On ANY
    // failure (flag-off 503, transport, non-map body, unknown phase) we degrade
    // to `broadcasting`, the safe compose/waiting state — NEVER `accepted`.
    try {
      // Read the conversation aggregate by its correlation key (== request id).
      // Prefer the host-resolved correlation key; fall back to the id argument
      // for callers/tests that only know the conversation id (unchanged legacy
      // behavior). Posting the conversation id as the correlationKey 404s on the
      // live chat-service (physical-run8 [Med] READ 404 #2).
      final resolvedKey = _correlationKey;
      final hasResolvedKey = resolvedKey != null && resolvedKey.isNotEmpty;
      final correlationKey = hasResolvedKey ? resolvedKey : conversationId;
      // BUG-14: the chat-service resolves a conversation ONLY by its correlation
      // key (== request id), NEVER by the conversation id. When the host DID
      // resolve a key but it is the conversation id itself (the jeeber opened
      // the accepted chat keyed on the conversation id, so no distinct
      // request-id correlation key exists), this read is a GUARANTEED 404
      // (`chat-service rejected the read conversation by correlation … does not
      // exist`, physical-run12 [Med] chat-load 404 ×2). Short-circuit to the
      // safe broadcasting phase instead of emitting a Core-Flow 404. A caller
      // that supplied NO key (legacy/tests) still falls back to the id argument
      // and issues the read unchanged.
      if (hasResolvedKey && correlationKey == conversationId) {
        return ConversationPhase.broadcasting;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/conversations',
        queryParameters: <String, Object?>{'correlationKey': correlationKey},
      );
      final data = response.data;
      if (data == null) return ConversationPhase.broadcasting;
      final phase = ConversationPhase.fromWire(data['phase'] as String?);
      // Gate the `accepted` phase on an ACTIVE winner, but only when the
      // aggregate actually carries a `participants` roster (the live
      // `JeebConversationResponse` always does). A response that omits the
      // roster entirely (degenerate / partial body) is trusted at its wire
      // phase — so a bare `{phase:"accepted"}` is not second-guessed, while an
      // aggregate that lists participants without a seated winner correctly
      // degrades to `broadcasting` (NEW-BUG-01).
      if (phase == ConversationPhase.accepted &&
          data['participants'] is List &&
          !_hasActiveWinner(data)) {
        return ConversationPhase.broadcasting;
      }
      return phase == ConversationPhase.unknown
          ? ConversationPhase.broadcasting
          : phase;
    } on DioException {
      return ConversationPhase.broadcasting;
    } catch (_) {
      return ConversationPhase.broadcasting;
    }
  }

  /// True when the conversation aggregate seats an ACTIVE `jeeber_winner`
  /// participant (role `jeeber_winner` and not yet `removed_at`). Gates the
  /// `accepted` phase so the accepted UI never renders without a real winner
  /// (NEW-BUG-01). Defensive on shape: a missing/non-list `participants` or a
  /// removed winner counts as "no active winner".
  bool _hasActiveWinner(Map<String, dynamic> data) {
    final participants = data['participants'];
    if (participants is! List) return false;
    return participants.whereType<Map>().any((p) {
      final role = p['role_in_convo'] as String?;
      final removedAt = p['removed_at'];
      return role == 'jeeber_winner' && removedAt == null;
    });
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async {
    // THE COMPOSE-SENTINEL DROP (fixed): in the order-compose flow the chat
    // screen mounts with the literal `new` route id and the cubit optimistically
    // dispatches the first composed line before any request/conversation exists.
    // Posting it to `/v1/conversations/new/messages` is a guaranteed 404, so the
    // opening message was silently dropped. We must NEVER send to the sentinel:
    // the first message's CONTENT is not lost — `OrderComposeCoordinator` carries
    // it as the created request's description (POST /v1/requests), and real chat
    // sends resume against the SERVER-MINTED conversation id once the Jeeber
    // accepts. Here we locally ack the optimistic bubble (no HTTP) so the UI
    // resolves cleanly and the compose→broadcast hook drives the create.
    if (_isUnresolvedConversation(conversationId)) {
      return message.copyWith(status: MessageStatus.sent);
    }
    // FROZEN Contract E (`AppendMessageBody`): `body` is a STRING for a text
    // message (`{ "kind":"text", "body":"on my way" }`); structured content for
    // non-text kinds rides in `payload`. The client previously sent `body` as an
    // object `{text:...}` for every kind → the gateway rejected it 400
    // (`$.body: could not be converted to System.String`), so NO chat message
    // ever persisted. `author_id` is stamped from the bearer JWT — never the
    // body — so the old `senderId` field was both wrong (`user-client-001`) and
    // ignored; it is dropped.
    final isText = message.kind == MessageKind.text;
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/conversations/$conversationId/messages',
      data: <String, Object?>{
        'kind': message.kind.wireName,
        if (isText) 'body': message.text else 'payload': _bodyFor(message),
      },
      options: Options(
        // Server-side idempotency keys off this header. It MUST be scoped to
        // the SENDER: `message.id` alone (`msg-{conversationId}-{localIndex}`)
        // is derived from a per-device local counter, so BOTH participants'
        // Nth message produced the SAME key — the backend then idempotency-
        // REPLAYED the first sender's message for the second sender, so neither
        // side's messages persisted or rendered (physical-run12 Step-5 [High]).
        // Scoping the key by the authenticated sender makes it globally unique
        // across participants while staying stable on retry.
        headers: <String, Object?>{
          'Idempotency-Key': _idempotencyKeyFor(message),
        },
      ),
    );
    final data = response.data;
    final serverId = data?['id'] as String?;
    // Once the server acknowledges, the message is at-least `sent`. The
    // delivered/read receipts arrive over the socket later.
    return message.copyWith(status: MessageStatus.sent).._serverIdProbe(serverId);
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    _ensureSocket(conversationId);
    return _events.stream;
  }

  /// The real network gateway opts INTO the cubit's HTTP-history poll fallback:
  /// its live transport is a WebSocket that may never establish against the
  /// mock backend (or a non-member / flaky socket), so the periodic re-pull of
  /// history is the inbound safety net. `DioChatGateway implements ChatGateway`
  /// (not `extends`), so the interface's default body is NOT inherited — this
  /// override must be declared explicitly or the class does not compile.
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
    // G4 (sprint-009 P0): RETAIN the handover code — the accept response is
    // the only wire moment the customer's app receives it. Persisted keyed by
    // delivery id so the tracking/OTP surfaces can show it, even after an app
    // restart. NEVER log it (DiagRedaction masks `handoverCode` keys).
    final handoverCode = _handoverCodeOf(response.data);
    if (_handoverCodeStore != null &&
        deliveryId != null &&
        handoverCode != null) {
      unawaited(
        _handoverCodeStore
            .save(deliveryId: deliveryId, code: handoverCode)
            .catchError((_) {}),
      );
    }
    // The mock backend flips the phase + writes the system message inside the
    // accept handler. We surface a synthetic phase event so the cubit reacts
    // immediately rather than waiting for the next socket frame; it carries
    // the delivery id so the cubit can expose the "Track order" path.
    if (!_events.isClosed) {
      _events.add(
        PhaseChanged(ConversationPhase.accepted, deliveryId: deliveryId),
      );
    }
    return OfferAcceptResult(
      deliveryId: deliveryId,
      handoverCode: handoverCode,
    );
  }

  /// True when [conversationId] does not yet identify a real backend
  /// conversation — the compose sentinel ([kComposeConversationSentinel]) or an
  /// empty id. Every id-scoped chat HTTP call short-circuits on this so the
  /// client never emits a request to a `/new` path that has no gateway route.
  bool _isUnresolvedConversation(String conversationId) =>
      conversationId.isEmpty ||
      conversationId == kComposeConversationSentinel;

  /// Participant-scoped `Idempotency-Key` for a chat message POST (BUG-13).
  ///
  /// `message.id` (`msg-{conversationId}-{localIndex}` / `voice-…`) is minted
  /// from a per-device counter, so it is NOT unique across the two participants
  /// — the customer's and the jeeber's Nth message collided, and the backend
  /// idempotency layer replayed the first sender's message for the second.
  /// Prefixing the SENDER (the authenticated [currentUserId], or a stable
  /// per-install/per-session fallback when unauthenticated) onto that already
  /// per-message-unique local id yields a key that is globally unique across
  /// participants yet identical when the SAME sender retries the SAME message.
  String _idempotencyKeyFor(DeliveryChatMessage message) {
    final sender =
        currentUserId.isNotEmpty ? currentUserId : _fallbackSenderScope;
    return '${message.id}-u-$sender';
  }

  /// Mints the [_fallbackSenderScope]: a random, session-stable token used to
  /// scope the idempotency key when no authenticated user id is available.
  static String _mintFallbackSenderScope() {
    final random = Random();
    final head = random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final tail = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return 'anon-$head$tail';
  }

  /// Defensive read of the server-created delivery id from the accept body.
  /// Accepts both `deliveryId` and snake_case `delivery_id`; anything else
  /// (missing field, non-string, empty) maps to null so a legacy/golden-less
  /// response never crashes the accept path.
  String? _deliveryIdOf(Map<String, dynamic>? body) {
    if (body == null) return null;
    final raw = body['deliveryId'] ?? body['delivery_id'];
    return raw is String && raw.trim().isNotEmpty ? raw : null;
  }

  /// Defensive read of the handover code from the accept body (G4). Accepts
  /// `handoverCode` and snake_case `handover_code`; missing/blank → null.
  String? _handoverCodeOf(Map<String, dynamic>? body) {
    if (body == null) return null;
    final raw = body['handoverCode'] ?? body['handover_code'];
    return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  }

  /// Upload a voice clip to `/v1/voice/transcribe` with a stable
  /// [idempotencyKey]. The endpoint returns a CDN URL + optional transcription.
  /// The 15s receive timeout is enforced so the bubble doesn't wait forever.
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
  // Socket plumbing
  // ---------------------------------------------------------------------------

  void _ensureSocket(String conversationId) {
    if (_socket != null) return;
    final socket =
        _socketFactory?.call(conversationId) ?? _defaultSocketFor(conversationId);
    _socket = socket;
    unawaited(_connectAndJoin(socket, conversationId));
  }

  ChatSocket _defaultSocketFor(String _) =>
      WebSocketChatSocket(uri: _socketBaseUri);

  Future<void> _connectAndJoin(ChatSocket socket, String conversationId) async {
    try {
      await socket.connect();
      socket.send(<String, Object?>{
        'event': 'phx_join',
        'topic': 'jeeb:chat:$conversationId',
        'payload': <String, Object?>{},
        'ref': '1',
      });
      socket.events.listen(_handleFrame);
    } catch (_) {
      // Surface as a soft failure — the cubit can still fetch via HTTP poll
      // while the socket retries on the next interaction.
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

  Map<String, Object?> _bodyFor(DeliveryChatMessage message) {
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
        // Photo bytes never leave the device in the new flow — the cubit
        // uploads them out of band and replaces the message with an `image`.
        // We post a placeholder body so the round trip still works in tests.
        return <String, Object?>{'caption': message.text};
      case MessageKind.system:
      case MessageKind.offerCard:
      case MessageKind.offerAccepted:
      case MessageKind.offerRejected:
        // These are server-emitted; the client doesn't post them. We still
        // serialize a minimal body so a misuse during testing is observable.
        return <String, Object?>{'text': message.text};
    }
  }

  DeliveryChatMessage _parseMessage(Map<String, dynamic> json) {
    // FROZEN `JeebMessageResponse` uses snake_case (`message_id`, `author_id`)
    // and a string `body` for text — DISTINCT from the camelCase the client
    // originally assumed. Tolerate BOTH wire shapes so messages render whether
    // the gateway emits snake_case (live) or the legacy camelCase (mock/socket).
    final id =
        (json['message_id'] as String?) ?? (json['id'] as String?) ?? '';
    final senderId =
        (json['author_id'] as String?) ?? (json['senderId'] as String?) ?? '';
    final author = senderId == currentUserId ? ChatAuthor.me : ChatAuthor.them;
    final sentAt = DateTime.tryParse(
              (json['createdAt'] ??
                      json['created_at'] ??
                      json['sentAt'] ??
                      json['sent_at'] ??
                      '')
                  as String? ??
                  '',
            )?.toLocal() ??
            DateTime.now();
    final kind = MessageKind.fromWire(json['kind'] as String?);
    // `body` is a plain string for text (frozen contract); structured payloads
    // arrive under `payload` (or a legacy map `body`). Normalize to the map the
    // builder consumes.
    final rawBody = json['body'] ?? json['payload'];
    final Map<String, Object?> body;
    if (rawBody is Map) {
      body = rawBody.cast<String, Object?>();
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
    final status = author == ChatAuthor.me
        ? MessageStatus.delivered
        : MessageStatus.delivered;
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
        // We never decode `photo` from the wire — the new flow uses `image`.
        // Fall through to a text bubble carrying the caption so the message
        // is still visible if a legacy server emits it.
        return DeliveryChatMessage.text(
          id: id,
          author: author,
          sentAt: sentAt,
          status: status,
          text: body['caption'] as String? ?? '',
        );
    }
  }
}

/// Extension hook — `_serverIdProbe` is a no-op today because
/// [DeliveryChatMessage] hashes by `id` (the client id). When the message
/// model grows a `serverId` (parity with [ChatMessage] in the canonical
/// wire shape), this is the swap point.
extension on DeliveryChatMessage {
  void _serverIdProbe(String? _) {}
}
