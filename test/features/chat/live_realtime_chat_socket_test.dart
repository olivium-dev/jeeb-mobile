import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/live_realtime_chat_socket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A [Dio] whose `/api/auth/token` POST returns a canned token without a real
/// network call, so the socket's token-mint step is deterministic in tests.
Dio _stubTokenDio({String token = 'tok-123'}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://realtime.test'));
  dio.httpClientAdapter = _FakeAdapter(token);
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.token);
  final String token;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'token': token, 'user_id': 'u', 'topics': const ['jeeb:chat']}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('LiveRealtimeChatSocket', () {
    // serverToClient: frames the fake server pushes down to the socket.
    // clientToServer: frames the socket sends up (captured into sentByClient).
    late StreamController<dynamic> serverToClient;
    late StreamController<dynamic> clientToServer;
    late List<String> sentByClient;

    tearDown(() async {
      await serverToClient.close();
      await clientToServer.close();
    });

    LiveRealtimeChatSocket build(String userId) {
      serverToClient = StreamController<dynamic>.broadcast();
      clientToServer = StreamController<dynamic>.broadcast();
      sentByClient = <String>[];
      clientToServer.stream.listen((dynamic m) => sentByClient.add(m as String));
      return LiveRealtimeChatSocket(
        currentUserId: userId,
        wsUri: Uri.parse('ws://realtime.test:5804/socket/websocket'),
        tokenDio: _stubTokenDio(),
        channelFactory: (_) =>
            _ReadyChannel(serverToClient.stream, clientToServer.sink),
      );
    }

    test('connect mints token, appends token+vsn, and issues a v2 phx_join '
        'on the jeeb:chat topic', () async {
      final socket = build('user-A');
      await socket.connect();
      // The join is issued via the legacy send() envelope DioChatGateway uses.
      socket.send(<String, Object?>{'event': 'phx_join'});
      await Future<void>.delayed(Duration.zero);

      expect(sentByClient, isNotEmpty);
      final join = jsonDecode(sentByClient.first) as List<dynamic>;
      // [joinRef, ref, topic, event, payload]
      expect(join[2], 'topic:jeeb:chat');
      expect(join[3], 'phx_join');
      await socket.close();
    });

    test('inbound event addressed to MY stream is normalized to new_msg', () async {
      final socket = build('user-A');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      // Server pushes a fan-out event on user-A's stream.
      serverToClient.add(jsonEncode([
        null,
        null,
        'topic:jeeb:chat',
        'event',
        {
          'stream': 'user:user-A',
          'data': {
            'messageId': 'm-1',
            'senderId': 'other-party',
            'type': 'text',
            'body': 'hello-live',
            'sentAt': '2026-06-21T10:00:00Z',
          },
        },
      ]));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
      expect(received.first['event'], 'new_msg');
      final payload = received.first['payload']! as Map<String, Object?>;
      expect(payload['id'], 'm-1');
      expect(payload['senderId'], 'other-party');
      expect(payload['kind'], 'text');
      expect((payload['body']! as Map)['text'], 'hello-live');
      await socket.close();
    });

    test('inbound event addressed to ANOTHER user\'s stream is filtered out',
        () async {
      final socket = build('user-A');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      serverToClient.add(jsonEncode([
        null,
        null,
        'topic:jeeb:chat',
        'event',
        {
          'stream': 'user:user-B', // not us
          'data': {
            'messageId': 'm-2',
            'senderId': 'x',
            'type': 'text',
            'body': 'not-for-me',
          },
        },
      ]));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isEmpty);
      await socket.close();
    });

    test('phx_reply / presence frames are ignored', () async {
      final socket = build('user-A');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      serverToClient.add(jsonEncode(
          ['1', '1', 'topic:jeeb:chat', 'phx_reply', {'status': 'ok'}]));
      serverToClient.add(jsonEncode(
          [null, null, 'topic:jeeb:chat', 'presence_state', {}]));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isEmpty);
      await socket.close();
    });
  });
}

/// Minimal [WebSocketChannel] fake whose `ready` resolves immediately (the real
/// channel awaits the handshake). Reads from [_stream] (server→client), writes
/// to [_sink] (client→server). [StreamChannelMixin] supplies the
/// transform/change boilerplate; it is re-exported by `web_socket_channel`, so
/// this needs no direct `stream_channel` dependency.
class _ReadyChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _ReadyChannel(this._stream, this._sink);
  final Stream<dynamic> _stream;
  final StreamSink<dynamic> _sink;

  @override
  Stream<dynamic> get stream => _stream;

  @override
  WebSocketSink get sink => _ReadySink(_sink);

  @override
  Future<void> get ready => Future<void>.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

class _ReadySink implements WebSocketSink {
  _ReadySink(this._inner);
  final StreamSink<dynamic> _inner;

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _inner.close();

  @override
  Future<void> get done => _inner.done;
}
