import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/chat_socket.dart';

/// Default [ChatSocket] backed by `web_socket_channel`.
///
/// One-shot: each instance manages a single connection. The cubit constructs
/// a fresh one on every reconnect attempt so half-open sockets can't leak
/// past the backoff cycle.
class WebSocketChatSocket implements ChatSocket {
  WebSocketChatSocket({
    required Uri uri,
    WebSocketChannel Function(Uri uri)? channelFactory,
  })  : _uri = uri,
        _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final Uri _uri;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();
  final StreamController<Object> _errors = StreamController.broadcast();
  bool _closed = false;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> connect() async {
    if (_channel != null) {
      throw StateError('WebSocketChatSocket already connected');
    }
    final channel = _channelFactory(_uri);
    _channel = channel;
    // `ready` is exposed in newer web_socket_channel; await it so we know
    // the handshake actually completed before declaring the cubit connected.
    await channel.ready;
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (Object error, StackTrace stack) {
        if (!_errors.isClosed) _errors.add(error);
      },
      onDone: () {
        // Peer closed: close the events stream so the cubit's onDone
        // listener fires reconnect logic.
        _shutdown();
      },
      cancelOnError: false,
    );
  }

  void _onFrame(dynamic frame) {
    if (_events.isClosed) return;
    try {
      final raw = frame is String ? frame : utf8.decode(frame as List<int>);
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _events.add(decoded.cast<String, Object?>());
      } else {
        _errors.add(FormatException('Non-object frame: $raw'));
      }
    } catch (e) {
      if (!_errors.isClosed) _errors.add(e);
    }
  }

  @override
  void send(Map<String, Object?> envelope) {
    final channel = _channel;
    if (channel == null || _closed) {
      throw StateError('WebSocketChatSocket.send called on closed socket');
    }
    channel.sink.add(jsonEncode(envelope));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // sink.close on an already-disposed channel can throw; swallow it —
      // the caller's intent (release the socket) is satisfied either way.
    }
    _channel = null;
    if (!_events.isClosed) await _events.close();
    if (!_errors.isClosed) await _errors.close();
  }

  void _shutdown() {
    // Called when the peer closes the stream. Close events synchronously so
    // the cubit can react in the same microtask.
    if (_closed) return;
    _closed = true;
    if (!_events.isClosed) _events.close();
    // Leave _errors open one tick longer so any trailing decode errors can
    // still flow; the cubit's done listener doesn't depend on it.
  }
}
