import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../support/fake_web_socket_channel.dart';

/// A real Phoenix-style join acknowledgement, without changing chat's socket fake.
class AcknowledgingCourierSocket extends FakeWebSocketChannel {
  AcknowledgingCourierSocket({
    this.acknowledgeJoin = true,
    this.closeCompletion,
    super.ready,
  });

  bool acknowledgeJoin;
  String joinStatus = 'ok';
  final Future<void>? closeCompletion;

  @override
  WebSocketSink get sink => _AcknowledgingSink(super.sink, (raw) {
    final frame = jsonDecode(raw as String) as List<dynamic>;
    if (acknowledgeJoin && frame[3] == 'phx_join') {
      serverToClient.add(
        jsonEncode([
          frame[0],
          frame[1],
          frame[2],
          'phx_reply',
          {'status': joinStatus, 'response': {}},
        ]),
      );
    }
  }, closeCompletion);
}

class _AcknowledgingSink implements WebSocketSink {
  _AcknowledgingSink(this.delegate, this.onSend, this.closeCompletion);
  final WebSocketSink delegate;
  final void Function(dynamic) onSend;
  final Future<void>? closeCompletion;

  @override
  void add(dynamic data) {
    delegate.add(data);
    onSend(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      delegate.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) => delegate.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await delegate.close(closeCode, closeReason);
    await closeCompletion;
  }

  @override
  Future<void> get done => delegate.done;
}
