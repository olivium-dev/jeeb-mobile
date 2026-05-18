import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_socket.dart';
import '../domain/delivery_chat_message.dart';
import 'web_socket_chat_socket.dart';

/// Dio + Phoenix-channel backed [ChatGateway].
///
/// HTTP side:
///   GET  /v1/chat/jeeb/conversations/{id}              → conversation row
///   GET  /v1/chat/jeeb/conversations/{id}/messages      → history (loadHistory)
///   POST /v1/chat/jeeb/conversations/{id}/messages      → send
///   POST /v1/offers/{offerId}/accept                    → acceptOffer
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
    ChatSocket Function(String conversationId)? socketFactory,
    Uri? socketBaseUri,
  })  : _dio = dio,
        _socketBaseUri = socketBaseUri ??
            Uri.parse(MockGatewayClient.webSocketUrl),
        _socketFactory = socketFactory;

  final Dio _dio;

  /// Id of the local user. Used to derive [ChatAuthor.me] vs `them` when
  /// folding inbound messages and to mark outgoing messages with the right
  /// `senderId`. The auth interceptor would normally inject this server-side;
  /// the mock just trusts whatever the client sends.
  final String currentUserId;

  final Uri _socketBaseUri;
  final ChatSocket Function(String conversationId)? _socketFactory;

  ChatSocket? _socket;
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/chat/jeeb/conversations/$conversationId/messages',
    );
    final data = response.data;
    if (data == null) return const <DeliveryChatMessage>[];
    final items = data['items'];
    if (items is! List) return const <DeliveryChatMessage>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .toList(growable: false);
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/chat/jeeb/conversations/$conversationId',
      );
      return ConversationPhase.fromWire(response.data?['phase'] as String?);
    } on DioException {
      return ConversationPhase.unknown;
    }
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async {
    final body = _bodyFor(message);
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/chat/jeeb/conversations/$conversationId/messages',
      data: <String, Object?>{
        'kind': message.kind.wireName,
        'senderId': currentUserId,
        'body': body,
      },
      options: Options(
        // Server-side idempotency in the mock keys off this header; bumping
        // it per send avoids accidental dedup if the user re-sends the same
        // text quickly.
        headers: <String, Object?>{
          'Idempotency-Key': message.id,
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

  @override
  Future<void> acceptOffer(String conversationId, String offerId) async {
    await _dio.post<Map<String, dynamic>>(
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
    // The mock backend flips the phase + writes the system message inside the
    // accept handler. We surface a synthetic phase event so the cubit reacts
    // immediately rather than waiting for the next socket frame.
    if (!_events.isClosed) {
      _events.add(const PhaseChanged(ConversationPhase.accepted));
    }
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
    final id = json['id'] as String? ?? '';
    final senderId = json['senderId'] as String? ?? '';
    final author = senderId == currentUserId ? ChatAuthor.me : ChatAuthor.them;
    final sentAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now();
    final kind = MessageKind.fromWire(json['kind'] as String?);
    final body = (json['body'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
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
