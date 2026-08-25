import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/realtime/phoenix_v2_frame.dart';
import '../domain/chat_socket.dart';

class LiveRealtimeChatSocket implements ChatSocket {
  LiveRealtimeChatSocket({
    required this.conversationId,
    required this.currentUserId,
    required this.topic,
    required this.connectToken,
    required this.ticket,
    required Uri wsUri,
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _wsUri = wsUri,
       _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final String conversationId;

  final String currentUserId;

  final String topic;

  final String ticket;

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
    final uri = _wsUri.replace(
      queryParameters: <String, String>{
        ..._wsUri.queryParameters,
        'vsn': '2.0.0',
        'token': connectToken,
      },
    );
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
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendRaw(PhoenixV2Frame.encodeTransportHeartbeat('${++_ref}'));
    });
  }

  void join() {
    final joinRef = '${++_ref}';
    _sendRaw(
      PhoenixV2Frame.encode(
        joinRef: joinRef,
        ref: joinRef,
        topic: topic,
        event: 'phx_join',
        payload: <String, Object?>{if (ticket.isNotEmpty) 'ticket': ticket},
      ),
    );
  }

  void _onFrame(dynamic frame) {
    if (_events.isClosed) return;
    try {
      final decoded = PhoenixV2Frame.decode(frame);
      if (decoded == null) return;
      if (decoded.topic != null && decoded.topic != topic) return;
      if (decoded.isLifecycle) return;
      final payload = decoded.payload;
      if (payload == null) return;
      final nested = payload['data'];
      final Map<String, Object?> data = nested is Map
          ? nested.cast<String, Object?>()
          : payload;
      final normalized = _normalize(data);
      if (normalized == null) return;
      _events.add(<String, Object?>{'event': 'new_msg', 'payload': normalized});
    } catch (e) {
      if (!_errors.isClosed) _errors.add(e);
    }
  }

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
    final createdAt =
        (data['created_at'] ?? data['sentAt'] ?? data['createdAt'])
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

  @override
  void send(Map<String, Object?> envelope) {
    if (_channel == null || _closed) {
      throw StateError('LiveRealtimeChatSocket.send on closed socket');
    }
    if (envelope['event'] == 'phx_join') {
      join();
      return;
    }
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
    } catch (_) {}
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
