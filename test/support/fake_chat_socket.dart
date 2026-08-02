import 'dart:async';

import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';

/// Programmable in-memory [ChatSocket] for cubit tests.
/// - [autoConnect] (default true) makes `connect()` succeed immediately.
///   Tests of failure handling pass `false` and override [connectError].
class FakeChatSocket implements ChatSocket {
  FakeChatSocket({this.autoConnect = true, this.connectError});

  bool autoConnect;
  Object? connectError;

  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final List<Map<String, Object?>> sent = [];
  bool connected = false;
  bool closed = false;
  int connectCalls = 0;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (!autoConnect) {
      final err = connectError ?? Exception('connect refused');
      throw err;
    }
    connected = true;
  }

  @override
  void send(Map<String, Object?> envelope) {
    if (!connected || closed) {
      throw StateError('FakeChatSocket.send on closed/disconnected');
    }
    sent.add(envelope);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    connected = false;
    if (!_events.isClosed) await _events.close();
    if (!_errors.isClosed) await _errors.close();
  }

  /// Push a JSON envelope as if the gateway sent it.
  void push(Map<String, Object?> envelope) {
    _events.add(envelope);
  }

  /// Push a transport error.
  void pushError(Object error) {
    _errors.add(error);
  }

  /// Simulate the peer closing the socket.
  Future<void> simulateDrop() async {
    connected = false;
    if (!_events.isClosed) await _events.close();
  }
}
