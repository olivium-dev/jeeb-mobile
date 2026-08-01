import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/realtime/phoenix_v2_frame.dart';
import '../domain/chat_socket.dart';

/// [ChatSocket] backed by the LIVE realtime-comunication-service
/// (Elixir/Phoenix), joining the **per-conversation** topic with a
/// **gateway-minted membership ticket**.
///
/// CHAT-CONTRACT (iter6 — canonical rewrite): the prior socket joined the
/// GLOBAL `topic:jeeb:chat` topic and kept only the frames whose
/// `stream == user:{currentUserId}` (a client-side per-recipient filter), and
/// it self-minted a `live_comm` token via the open dev minter. Both deviate
/// from the canonical contract:
///
///   * the canonical realtime topic is **PER-CONVERSATION**
///     (`jeeb_conversation:<conversation_id>` — the topic the gateway's
///     `/v1/realtime/jeeb:chat:{id}` descriptor hands back). Per-recipient
///     fan-out is the SERVER's decision (chat-service VisibilityFilter), NOT a
///     client `stream` filter;
///   * the join is membership-authorized by a **gateway-minted ticket**
///     (`RealtimeChannelDescriptor.ticket`, a short-lived signed JWT scoped to
///     `(conversation, viewer, role)`), NOT a self-minted token.
///
/// This socket therefore takes the resolved [topic] + [ticket] from the
/// caller (the gateway resolves them via the `/v1/realtime/jeeb:chat:{id}`
/// pre-check) and:
///   1. **Connect** — `ws(s)://<host>/socket/websocket?vsn=2.0.0`
///      (`&ticket=<jwt>` is appended so a Phoenix `connect/3` that authorizes
///      on the socket params also passes).
///   2. **Join** — Phoenix v2 array frame
///      `[joinRef, ref, "<topic>", "phx_join", {"ticket": "<jwt>"}]` — the
///      ticket travels in the join params (canonical), so the channel
///      `join/3` membership check passes.
///   3. **Inbound** — `[joinRef, ref, "<topic>", "<event>", <payload>]`. Every
///      frame on the per-conversation topic is for this thread (the server
///      already targeted the subscriber), so there is NO client-side stream
///      filter. We normalize the message envelope onto the
///      `{id, senderId, kind, body, createdAt}` shape [DioChatGateway] consumes
///      and emit it as `{event:'new_msg', payload}`.
///
/// One-shot, mirrors the [ChatSocket] lifecycle so [DioChatGateway] can swap it
/// in transparently. Any failure in [connect] throws and [DioChatGateway]
/// degrades to HTTP-history only (degrade-don't-fail).
class LiveRealtimeChatSocket implements ChatSocket {
  LiveRealtimeChatSocket({
    required this.conversationId,
    required this.currentUserId,
    required this.topic,
    required this.ticket,
    required Uri wsUri,
    this.connectToken = '',
    WebSocketChannel Function(Uri uri)? channelFactory,
  })  : _wsUri = wsUri,
        _channelFactory = channelFactory ?? WebSocketChannel.connect;

  /// The server-minted conversation id this socket is scoped to.
  final String conversationId;

  /// The local user id — used to fold inbound message authorship (`me` vs
  /// `them`) downstream; NOT used to filter frames (the per-conversation topic
  /// is already scoped server-side).
  final String currentUserId;

  /// The realtime topic to join, from the gateway descriptor
  /// (`jeeb_conversation:<conversation_id>`).
  final String topic;

  /// The gateway-minted membership ticket presented on the WS join params.
  /// May be empty only when the gateway could not mint one — the join still
  /// attempts (the realtime channel rejects an unauthorized join, which
  /// degrades to HTTP-history).
  final String ticket;

  /// The realtime CONNECT token (Guardian) minted by the resolver from the
  /// realtime open minter (`POST /api/auth/token`). REQUIRED on the socket
  /// upgrade — the Phoenix `connect/3` establishes `user_id` from this `token`
  /// query param; without it the upgrade is rejected `missing_token` and NO
  /// live frame ever arrives (the membership ticket alone authorizes only the
  /// channel JOIN, not the socket CONNECT). May be empty when minting failed —
  /// the connect still attempts and degrades to HTTP-history on rejection.
  final String connectToken;

  final Uri _wsUri;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();
  final StreamController<Object> _errors = StreamController.broadcast();
  bool _closed = false;
  int _ref = 0;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> connect() async {
    if (_channel != null) {
      throw StateError('LiveRealtimeChatSocket already connected');
    }
    final uri = _wsUri.replace(queryParameters: <String, String>{
      ..._wsUri.queryParameters,
      'vsn': '2.0.0',
      // The Guardian connect token establishes `user_id` on the socket — the
      // realtime `connect/3` REQUIRES it (a ticket-only connect is rejected
      // `missing_token`). Without it no inbound frame ever arrives.
      if (connectToken.isNotEmpty) 'token': connectToken,
      // The ticket also rides the connect params so a realtime `connect/3`
      // that authorizes the socket (rather than the channel) accepts it; it is
      // re-presented on the channel join (below) for the V2 ticket-auth path.
      if (ticket.isNotEmpty) 'ticket': ticket,
    });
    final channel = _channelFactory(uri);
    _channel = channel;
    await channel.ready;
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (Object error, StackTrace stack) {
        if (!_errors.isClosed) _errors.add(error);
      },
      onDone: _shutdown,
      cancelOnError: false,
    );
    // Phoenix heartbeat so the server doesn't reap the connection.
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendRaw(PhoenixV2Frame.encodeTransportHeartbeat('${++_ref}'));
    });
  }

  /// Phoenix v2 join on the PER-CONVERSATION topic, presenting the
  /// gateway-minted ticket in the join params:
  /// `[joinRef, ref, "<topic>", "phx_join", {"ticket": "<jwt>"}]`.
  void join() {
    final joinRef = '${++_ref}';
    _sendRaw(PhoenixV2Frame.encode(
      joinRef: joinRef,
      ref: joinRef,
      topic: topic,
      event: 'phx_join',
      payload: <String, Object?>{if (ticket.isNotEmpty) 'ticket': ticket},
    ));
  }

  void _onFrame(dynamic frame) {
    if (_events.isClosed) return;
    try {
      // Phoenix v2 framing lives in ONE place now — `PhoenixV2Frame` — shared
      // with `CourierPositionSocket`. The two sockets differ in almost every
      // other respect (different channel, join params, keepalive and payload
      // projection) but they must not be able to disagree about what a frame
      // IS.
      final decoded = PhoenixV2Frame.decode(frame);
      if (decoded == null) return;
      // Only frames on OUR per-conversation topic (defensive; this socket joins
      // exactly one topic).
      if (decoded.topic != null && decoded.topic != topic) return;
      // Ignore lifecycle/control frames — phx_reply / presence_* / heartbeat.
      if (decoded.isLifecycle) return;
      final payload = decoded.payload;
      if (payload == null) return;
      // The product message payload may be the frame payload itself, or nested
      // under `data` (the gateway fan-out envelope). Accept both.
      final nested = payload['data'];
      final Map<String, Object?> data =
          nested is Map ? nested.cast<String, Object?>() : payload;
      final normalized = _normalize(data);
      if (normalized == null) return;
      _events.add(<String, Object?>{
        'event': 'new_msg',
        'payload': normalized,
      });
    } catch (e) {
      if (!_errors.isClosed) _errors.add(e);
    }
  }

  /// Project the inbound message envelope onto the normalized message shape
  /// [DioChatGateway]'s frame handler expects
  /// (`{id, senderId, kind, body, createdAt}`). Accepts both the canonical
  /// chat-service envelope (`{message_id, author_id, kind, body, created_at}`)
  /// and the legacy gateway fan-out shape (`{messageId, senderId, type, body,
  /// sentAt}`). `body` may be a string (text) or an already-structured object.
  Map<String, Object?>? _normalize(Map<String, Object?> data) {
    final id =
        (data['message_id'] ?? data['messageId'] ?? data['id']) as String?;
    final senderId =
        (data['author_id'] ?? data['senderId'] ?? data['sender_id']) as String?;
    if (id == null || senderId == null) return null;
    final kind = (data['kind'] ?? data['type']) as String? ?? 'text';
    final rawBody = data['body'];
    final Map<String, Object?> body;
    if (rawBody is Map) {
      body = rawBody.cast<String, Object?>();
    } else if (rawBody is String) {
      body = <String, Object?>{'text': rawBody};
    } else {
      body = const <String, Object?>{};
    }
    final createdAt = (data['created_at'] ?? data['sentAt'] ?? data['createdAt'])
            as String? ??
        DateTime.now().toUtc().toIso8601String();
    return <String, Object?>{
      'id': id,
      'senderId': senderId,
      'kind': kind,
      'body': body,
      'createdAt': createdAt,
    };
  }

  /// [DioChatGateway] calls [send] with the legacy object-frame join envelope
  /// (`{event:'phx_join', ...}`). We interpret that as the trigger to issue the
  /// correct Phoenix v2 [join] on the resolved per-conversation [topic].
  @override
  void send(Map<String, Object?> envelope) {
    if (_channel == null || _closed) {
      throw StateError('LiveRealtimeChatSocket.send on closed socket');
    }
    if (envelope['event'] == 'phx_join') {
      join();
      return;
    }
    // No other client→server sends are needed for inbound push.
  }

  void _sendRaw(String frame) {
    final channel = _channel;
    if (channel == null || _closed) return;
    channel.sink.add(frame);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Already-disposed sink — the intent (release) is satisfied.
    }
    _channel = null;
    if (!_events.isClosed) await _events.close();
    if (!_errors.isClosed) await _errors.close();
  }

  void _shutdown() {
    if (_closed) return;
    _closed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (!_events.isClosed) _events.close();
  }
}
