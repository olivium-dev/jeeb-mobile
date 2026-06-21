import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/chat_socket.dart';

/// [ChatSocket] backed by the LIVE realtime-comunication-service
/// (Elixir/Phoenix "LiveComm", `:5804`).
///
/// CHAT-FIX (iter6 / ws): the default [WebSocketChatSocket] spoke a mock
/// Phoenix shim shape (object frames, topic `jeeb:chat:{conversationId}`,
/// `new_msg` event, no auth) against a dead `:3056` host. The live service
/// uses a different, confirmed contract (probed on MSI):
///
///   1. **Token** — `POST /api/auth/token` `{user_id, role, scopes, topics}`
///      → `{token}`. The dev minter issues a `live_comm` JWT for any caller; we
///      request `subscribe` scope on the `jeeb:chat` topic.
///   2. **Connect** — `ws://<host>:5804/socket/websocket?token=<jwt>&vsn=2.0.0`.
///   3. **Join** — Phoenix v2 array frame
///      `[joinRef, ref, "topic:jeeb:chat", "phx_join", {}]`.
///   4. **Inbound** — `[joinRef, ref, "topic:jeeb:chat", "event",
///      {stream: "user:{recipientId}", data: {...}, ...}]`. We keep only the
///      frame whose `stream` equals our own `user:{currentUserId}` (the
///      per-recipient fan-out filter) and project the gateway's fan-out
///      `data` (`{messageId, senderId, type, body, sentAt}`) onto the
///      normalized `{event:'new_msg', payload:{id, senderId, kind, body,
///      createdAt}}` shape that [DioChatGateway]'s frame handler already
///      consumes — so the gateway/cubit/UI append path is unchanged.
///
/// One-shot, mirrors [WebSocketChatSocket]'s lifecycle so [DioChatGateway] can
/// swap it in transparently. Any failure in [connect] (token mint, handshake)
/// throws, and [DioChatGateway._connectAndJoin] degrades to HTTP-history only.
class LiveRealtimeChatSocket implements ChatSocket {
  LiveRealtimeChatSocket({
    required this.currentUserId,
    Uri? wsUri,
    Uri? httpBase,
    Dio? tokenDio,
    WebSocketChannel Function(Uri uri)? channelFactory,
  })  : _wsUri = wsUri ?? Uri.parse(MockGatewayClient.webSocketUrl),
        _httpBase = httpBase ?? MockGatewayClient.realtimeHttpBase,
        _tokenDio = tokenDio,
        _channelFactory = channelFactory ?? WebSocketChannel.connect;

  /// The local user id; the realtime fan-out stream we keep is
  /// `user:{currentUserId}` (the gateway encodes the recipient there).
  final String currentUserId;

  final Uri _wsUri;
  final Uri _httpBase;
  final Dio? _tokenDio;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();
  final StreamController<Object> _errors = StreamController.broadcast();
  bool _closed = false;
  int _ref = 0;

  /// The recipient stream this socket cares about (`user:{currentUserId}`).
  String get _myStream => 'user:$currentUserId';

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> connect() async {
    if (_channel != null) {
      throw StateError('LiveRealtimeChatSocket already connected');
    }
    final token = await _mintToken();
    final uri = _wsUri.replace(queryParameters: <String, String>{
      ..._wsUri.queryParameters,
      'token': token,
      'vsn': '2.0.0',
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
      _sendRaw(<Object?>[null, '${++_ref}', 'phoenix', 'heartbeat', <String, Object?>{}]);
    });
  }

  /// Mint a `live_comm` subscribe token for [currentUserId] on the `jeeb:chat`
  /// topic via the open dev minter. Throws on failure so the gateway degrades.
  Future<String> _mintToken() async {
    final dio = _tokenDio ??
        Dio(BaseOptions(
          baseUrl: _httpBase.toString(),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: const {'Content-Type': 'application/json'},
        ));
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/token',
      data: <String, Object?>{
        'user_id': currentUserId,
        'role': 'client',
        'scopes': const <String>['subscribe'],
        'topics': const <String>['jeeb:chat'],
      },
    );
    final token = response.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('realtime token mint returned no token');
    }
    return token;
  }

  /// Phoenix v2 join: `[joinRef, ref, "topic:jeeb:chat", "phx_join", {}]`.
  void join() {
    final joinRef = '${++_ref}';
    _sendRaw(<Object?>[joinRef, joinRef, 'topic:jeeb:chat', 'phx_join', <String, Object?>{}]);
  }

  void _onFrame(dynamic frame) {
    if (_events.isClosed) return;
    try {
      final raw = frame is String ? frame : utf8.decode(frame as List<int>);
      final decoded = jsonDecode(raw);
      // Phoenix v2 frames are arrays: [joinRef, ref, topic, event, payload].
      if (decoded is! List || decoded.length < 5) return;
      final event = decoded[3] as String?;
      if (event != 'event') return; // ignore phx_reply / presence_* / heartbeat
      final payload = decoded[4];
      if (payload is! Map) return;
      // Per-recipient filter: only frames addressed to MY stream.
      final stream = payload['stream'] as String?;
      if (stream != null && stream != _myStream) return;
      final data = payload['data'];
      if (data is! Map) return;
      final normalized = _normalize(data.cast<String, Object?>());
      if (normalized == null) return;
      _events.add(<String, Object?>{
        'event': 'new_msg',
        'payload': normalized,
      });
    } catch (e) {
      if (!_errors.isClosed) _errors.add(e);
    }
  }

  /// Project the gateway fan-out `data`
  /// (`{messageId, senderId, type, body, sentAt}`) onto the normalized message
  /// shape [DioChatGateway._parseMessage] expects
  /// (`{id, senderId, kind, body, createdAt}`). `body` may be a string (text)
  /// or an already-structured object.
  Map<String, Object?>? _normalize(Map<String, Object?> data) {
    final id = (data['messageId'] ?? data['id']) as String?;
    final senderId = data['senderId'] as String?;
    if (id == null || senderId == null) return null;
    final kind = (data['type'] ?? data['kind']) as String? ?? 'text';
    final rawBody = data['body'];
    final Map<String, Object?> body;
    if (rawBody is Map) {
      body = rawBody.cast<String, Object?>();
    } else if (rawBody is String) {
      body = <String, Object?>{'text': rawBody};
    } else {
      body = const <String, Object?>{};
    }
    final createdAt = (data['sentAt'] ?? data['createdAt']) as String? ??
        DateTime.now().toUtc().toIso8601String();
    return <String, Object?>{
      'id': id,
      'senderId': senderId,
      'kind': kind,
      'body': body,
      'createdAt': createdAt,
    };
  }

  /// [DioChatGateway] calls [send] with the old object-frame join envelope
  /// (`{event:'phx_join', topic:'jeeb:chat:{id}', ...}`). We ignore that legacy
  /// shape and issue the correct Phoenix v2 [join] on the live topic instead —
  /// the conversation scoping happens via the recipient stream filter, not the
  /// topic, on the live service.
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

  void _sendRaw(List<Object?> frame) {
    final channel = _channel;
    if (channel == null || _closed) return;
    channel.sink.add(jsonEncode(frame));
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
