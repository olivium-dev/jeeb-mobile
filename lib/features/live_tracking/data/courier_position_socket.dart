import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/realtime/phoenix_v2_frame.dart';
import '../domain/courier_position_channel.dart';

/// 20s server keepalive (75s timeout gate). Not a poll.
const Duration kCourierPositionKeepAlive = Duration(seconds: 20);
const Duration kCourierPositionJoinTimeout = Duration(seconds: 10);
const Duration kCourierPositionCloseTimeout = Duration(seconds: 2);

/// A safe classification: never include socket URLs, tokens or server payloads.
class CourierPositionSocketException implements Exception {
  const CourierPositionSocketException(this.failure);

  final CourierPositionOpenFailure failure;

  @override
  String toString() => 'CourierPositionSocketException(${failure.name})';
}

class CourierPositionSocket {
  CourierPositionSocket({
    required Uri socketUri,
    required String token,
    required String channel,
    required String stream,
    WebSocketChannel Function(Uri uri)? channelFactory,
    Duration keepAlive = kCourierPositionKeepAlive,
    Duration joinTimeout = kCourierPositionJoinTimeout,
    Duration closeTimeout = kCourierPositionCloseTimeout,
  }) : _socketUri = socketUri,
       _token = token,
       _channel = channel,
       _stream = stream,
       _keepAlive = keepAlive,
       _joinTimeout = joinTimeout,
       _closeTimeout = closeTimeout,
       _channelFactory = channelFactory ?? WebSocketChannel.connect {
    _out = StreamController<CourierPositionFix>(onCancel: close);
  }

  final Uri _socketUri;
  final String _token;
  final String _channel;
  final String _stream;
  final Duration _keepAlive;
  final Duration _joinTimeout;
  final Duration _closeTimeout;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  late final StreamController<CourierPositionFix> _out;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _frames;
  Timer? _keepAliveTimer;
  bool _closed = false;
  bool _started = false;
  bool _joined = false;
  Completer<void>? _joinResult;
  Future<void>? _closing;
  int _ref = 0;
  String? _joinRef;

  Stream<CourierPositionFix> get positions => _out.stream;

  /// Counts arrivals, not open attempts (silent feed detector).
  int get frameCount => _frameCount;
  int _frameCount = 0;

  Future<void> connect() async {
    if (_started || _closed) {
      throw StateError('CourierPositionSocket already connected');
    }
    _started = true;
    final result = Completer<void>();
    _joinResult = result;
    // One bounded deadline includes transport setup AND the correlated join.
    // Attach the error handler before a synchronous factory/stream can fail.
    final joined = result.future.timeout(
      _joinTimeout,
      onTimeout: () => throw const CourierPositionSocketException(
        CourierPositionOpenFailure.joinTimeout,
      ),
    );
    try {
      final uri = _socketUri.replace(
        queryParameters: <String, String>{
          ..._socketUri.queryParameters,
          'vsn': '2.0.0',
          'token': _token,
        },
      );
      final socket = _channelFactory(uri);
      _socket = socket;
      _frames = socket.stream.listen(
        _onFrame,
        onError: (Object _, StackTrace _) => _fail(),
        onDone: _fail,
        cancelOnError: false,
      );
      unawaited(
        socket.ready.then((_) {
          if (!_closed) _join();
        }, onError: (Object _, StackTrace _) => _fail()),
      );
    } catch (_) {
      _fail();
    }
    try {
      await joined;
      if (_closed) {
        throw const CourierPositionSocketException(
          CourierPositionOpenFailure.connectFailed,
        );
      }
      _keepAliveTimer = Timer.periodic(_keepAlive, (_) => _sendKeepAlive());
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _join() {
    final joinRef = '${++_ref}';
    _joinRef = joinRef;
    _send(
      PhoenixV2Frame.encode(
        joinRef: joinRef,
        ref: joinRef,
        topic: _channel,
        event: 'phx_join',
        payload: <String, Object?>{
          'streams': <String>[_stream],
        },
      ),
    );
  }

  void _sendKeepAlive() {
    _send(
      PhoenixV2Frame.encode(
        joinRef: _joinRef,
        ref: '${++_ref}',
        topic: _channel,
        event: 'ping',
      ),
    );
    _send(PhoenixV2Frame.encodeTransportHeartbeat('${++_ref}'));
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || _closed) return;
    try {
      socket.sink.add(frame);
    } catch (_) {
      _fail();
    }
  }

  void _onFrame(dynamic raw) {
    if (_closed || _out.isClosed) return;
    final frame = PhoenixV2Frame.decode(raw);
    if (frame == null) return;
    if (frame.topic != _channel) return;
    if (frame.joinRef != null && frame.joinRef != _joinRef) return;
    if (frame.event == 'phx_reply' &&
        frame.joinRef == _joinRef &&
        frame.ref == _joinRef &&
        !_joined) {
      if (frame.payload?['status'] == 'ok') {
        _joined = true;
        _joinResult?.complete();
      } else {
        _fail(CourierPositionOpenFailure.joinRejected);
      }
      return;
    }
    // A Phoenix channel can die while its WebSocket remains connected.
    if (frame.event == 'phx_error' || frame.event == 'phx_close') {
      _fail();
      return;
    }
    if (frame.isLifecycle) return;
    if (!_joined) return;
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
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    final accuracy = data['accuracy'];
    final timestamp = data['timestamp'];
    return CourierPositionFix(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      accuracy: accuracy is num ? accuracy.toDouble() : null,
      timestamp: timestamp is String ? DateTime.tryParse(timestamp) : null,
      jeeberId: data['jeeberId'] is String ? data['jeeberId'] as String : null,
    );
  }

  void _fail([
    CourierPositionOpenFailure failure =
        CourierPositionOpenFailure.connectFailed,
  ]) {
    final result = _joinResult;
    if (result != null && !result.isCompleted) {
      result.completeError(CourierPositionSocketException(failure));
    }
    unawaited(close());
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _joined = false;
    final result = _joinResult;
    if (result != null && !result.isCompleted) {
      result.completeError(
        const CourierPositionSocketException(
          CourierPositionOpenFailure.connectFailed,
        ),
      );
    }
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    // A peer that never completes the closing handshake must not defeat the
    // join deadline or leave a screen's terminal teardown waiting indefinitely.
    try {
      await _frames?.cancel().timeout(_closeTimeout);
    } catch (_) {
      // Cancellation has been requested; closed guards reject any late frame.
    }
    _frames = null;
    try {
      await _socket?.sink.close().timeout(_closeTimeout);
    } catch (_) {}
    _socket = null;
    // TRAP: can't await StreamController.close() inside its own cancel callback.
    if (!_out.isClosed) unawaited(_out.close());
  }
}
