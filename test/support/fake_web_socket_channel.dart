import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A [WebSocketChannel] double whose two directions are ordinary streams, so a
/// test can BE the server: push frames down [serverToClient] and read what the
/// client wrote out of [sentByClient].
///
/// This is not a mock of the subject. The subject is the Phoenix client's wire
/// behaviour — the URL it dials, the frames it writes, and what it does with
/// the frames it is given — and none of that is observable without something on
/// the other end of the socket. What it substitutes is the TCP connection, at
/// the one seam (`channelFactory`) the production class already exposes for
/// exactly this; everything above that seam is the shipped code.
class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel({Future<void>? ready})
      : _readyFuture = ready ?? Future<void>.value();

  /// Frames the "server" pushes to the client.
  final StreamController<dynamic> serverToClient =
      StreamController<dynamic>.broadcast();

  /// Every frame the client wrote, in order.
  final List<String> sentByClient = <String>[];

  final Future<void> _readyFuture;

  /// Whether the client closed its sink. The teardown assertion: a subscription
  /// that is cancelled must CLOSE the socket, not merely stop reading it.
  bool sinkClosed = false;

  @override
  Stream<dynamic> get stream => serverToClient.stream;

  @override
  WebSocketSink get sink => _FakeSink(this);

  @override
  Future<void> get ready => _readyFuture;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  Future<void> dispose() async {
    if (!serverToClient.isClosed) await serverToClient.close();
  }
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._channel);
  final FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) => _channel.sentByClient.add(data as String);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _channel.sinkClosed = true;
    await _channel.dispose();
  }

  @override
  Future<void> get done => Future<void>.value();
}
