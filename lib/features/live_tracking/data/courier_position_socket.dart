import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/realtime/phoenix_v2_frame.dart';
import '../domain/courier_position_channel.dart';

/// 20s server keepalive (75s timeout gate). Not a poll.
const Duration kCourierPositionKeepAlive = Duration(seconds: 20);

class CourierPositionSocket {
  CourierPositionSocket({
    required Uri socketUri,
    required String token,
    required String channel,
    required String stream,
    WebSocketChannel Function(Uri uri)? channelFactory,
    Duration keepAlive = kCourierPositionKeepAlive,
  })  : _socketUri = socketUri,
        _token = token,
        _channel = channel,
        _stream = stream,
        _keepAlive = keepAlive,
        _channelFactory = channelFactory ?? WebSocketChannel.connect {
    _out = StreamController<CourierPositionFix>(onCancel: close);
  }

  final Uri _socketUri;
  final String _token;
  final String _channel;
  final String _stream;
  final Duration _keepAlive;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  late final StreamController<CourierPositionFix> _out;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _frames;
  Timer? _keepAliveTimer;
  bool _closed = false;
  int _ref = 0;
  String? _joinRef;

  Stream<CourierPositionFix> get positions => _out.stream;

  /// Counts arrivals, not open attempts (silent feed detector).
  int get frameCount => _frameCount;
  int _frameCount = 0;

  Future<void> connect() async {
    if (_socket != null) {
      throw StateError('CourierPositionSocket already connected');
    }
    final uri = _socketUri.replace(queryParameters: <String, String>{
      ..._socketUri.queryParameters,
      'vsn': '2.0.0',
      'token': _token,
    });
    final socket = _channelFactory(uri);
    _socket = socket;
    await socket.ready;
    _frames = socket.stream.listen(
      _onFrame,
      onError: (Object _, StackTrace _) => unawaited(close()),
      onDone: () => unawaited(close()),
      cancelOnError: false,
    );
    _join();
    _keepAliveTimer = Timer.periodic(_keepAlive, (_) => _sendKeepAlive());
  }

  void _join() {
    final joinRef = '${++_ref}';
    _joinRef = joinRef;
    _send(PhoenixV2Frame.encode(
      joinRef: joinRef,
      ref: joinRef,
      topic: _channel,
      event: 'phx_join',
      payload: <String, Object?>{
        'streams': <String>[_stream],
      },
    ));
  }

  void _sendKeepAlive() {
    _send(PhoenixV2Frame.encode(
      joinRef: _joinRef,
      ref: '${++_ref}',
      topic: _channel,
      event: 'ping',
    ));
    _send(PhoenixV2Frame.encodeTransportHeartbeat('${++_ref}'));
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || _closed) return;
    try {
      socket.sink.add(frame);
    } catch (_) {
    }
  }

  void _onFrame(dynamic raw) {
    if (_out.isClosed) return;
    final frame = PhoenixV2Frame.decode(raw);
    if (frame == null) return;
    if (frame.topic != null && frame.topic != _channel) return;
    if (frame.isLifecycle) return;
    if (frame.event != 'event') return;
    final envelope = frame.payload;
    if (envelope == null) return;
    // TRAP: server ignores join's streams filter; must enforce here.
    if (envelope['stream'] != _stream) return;
    final data = envelope['data'];
    if (data is! Map) return;
    final fix = _readFix(data.cast<String, Object?>());
    if (fix == null) return;
    _frameCount++;
    _out.add(fix);
  }

  /// TRAP: JSON 33 decodes to int; `as double` throws. Common silent-feed bug.
  CourierPositionFix? _readFix(Map<String, Object?> data) {
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is! num || lng is! num) return null;
    final accuracy = data['accuracy'];
    final timestamp = data['timestamp'];
    return CourierPositionFix(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      accuracy: accuracy is num ? accuracy.toDouble() : null,
      timestamp: timestamp is String ? DateTime.tryParse(timestamp) : null,
      jeeberId: data['jeeberId'] as String?,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await _frames?.cancel();
    _frames = null;
    try {
      await _socket?.sink.close();
    } catch (_) {
    }
    _socket = null;
    // TRAP: can't await StreamController.close() inside its own cancel callback.
    if (!_out.isClosed) unawaited(_out.close());
  }
}
