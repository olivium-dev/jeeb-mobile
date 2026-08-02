import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/chat_socket.dart';

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
    await channel.ready;
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (Object error, StackTrace stack) {
        if (!_errors.isClosed) _errors.add(error);
      },
      onDone: () {
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
    }
    _channel = null;
    if (!_events.isClosed) await _events.close();
    if (!_errors.isClosed) await _errors.close();
  }

  void _shutdown() {
    if (_closed) return;
    _closed = true;
    if (!_events.isClosed) _events.close();
  }
}
