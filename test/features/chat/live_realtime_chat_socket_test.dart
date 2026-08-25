import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/live_realtime_chat_socket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Chat connects with the Guardian token and joins the gateway-authorized
/// `jeeb:chat:<conversation_id>` topic with a distinct membership ticket.
void main() {
  group('LiveRealtimeChatSocket (Guardian connect + membership join)', () {
    late StreamController<dynamic> serverToClient;
    late StreamController<dynamic> clientToServer;
    late List<String> sentByClient;

    tearDown(() async {
      await serverToClient.close();
      await clientToServer.close();
    });

    LiveRealtimeChatSocket build({
      String conversationId = 'conv-1',
      String userId = 'user-A',
      String connectToken = 'guardian-connect-token',
      String ticket = 'ticket-jwt',
    }) {
      serverToClient = StreamController<dynamic>.broadcast();
      clientToServer = StreamController<dynamic>.broadcast();
      sentByClient = <String>[];
      clientToServer.stream.listen(
        (dynamic m) => sentByClient.add(m as String),
      );
      return LiveRealtimeChatSocket(
        conversationId: conversationId,
        currentUserId: userId,
        topic: 'jeeb:chat:$conversationId',
        connectToken: connectToken,
        ticket: ticket,
        wsUri: Uri.parse('ws://realtime.test/socket/websocket'),
        channelFactory: (_) =>
            _ReadyChannel(serverToClient.stream, clientToServer.sink),
      );
    }

    test(
      'connect sends Guardian token + vsn but never membership ticket',
      () async {
        Uri? connectedUri;
        serverToClient = StreamController<dynamic>.broadcast();
        clientToServer = StreamController<dynamic>.broadcast();
        sentByClient = <String>[];
        clientToServer.stream.listen(
          (dynamic m) => sentByClient.add(m as String),
        );
        final socket = LiveRealtimeChatSocket(
          conversationId: 'conv-9',
          currentUserId: 'user-A',
          topic: 'jeeb:chat:conv-9',
          connectToken: 'guardian-connect-9',
          ticket: 'membership-ticket-9',
          wsUri: Uri.parse('ws://realtime.test/socket/websocket'),
          channelFactory: (uri) {
            connectedUri = uri;
            return _ReadyChannel(serverToClient.stream, clientToServer.sink);
          },
        );
        await socket.connect();
        expect(connectedUri!.queryParameters['token'], 'guardian-connect-9');
        expect(connectedUri!.queryParameters, isNot(contains('ticket')));
        expect(connectedUri!.queryParameters['vsn'], '2.0.0');
        await socket.close();
      },
    );

    test('issues a v2 phx_join on the PER-CONVERSATION topic carrying the '
        'gateway ticket in the join params', () async {
      final socket = build(
        conversationId: 'conv-1',
        connectToken: 'guardian-connect-1',
        ticket: 'membership-ticket-1',
      );
      await socket.connect();
      // The join is triggered via the legacy send() envelope DioChatGateway uses.
      socket.send(<String, Object?>{'event': 'phx_join'});
      await Future<void>.delayed(Duration.zero);

      // First non-heartbeat client frame is the join.
      final joinRaw = sentByClient.firstWhere((f) => f.contains('phx_join'));
      final join = jsonDecode(joinRaw) as List<dynamic>;
      // [joinRef, ref, topic, event, payload]
      expect(join[2], 'jeeb:chat:conv-1');
      expect(join[3], 'phx_join');
      expect((join[4] as Map)['ticket'], 'membership-ticket-1');
      expect(join[4] as Map, isNot(contains('token')));
      await socket.close();
    });

    test('inbound event on the per-conversation topic is normalized to new_msg '
        '(no client-side stream filter)', () async {
      final socket = build(conversationId: 'conv-1');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      // The server already targeted this subscriber — there is NO `stream`
      serverToClient.add(
        jsonEncode([
          null,
          null,
          'jeeb:chat:conv-1',
          'message_created',
          {
            'message_id': 'm-1',
            'author_id': 'other-party',
            'kind': 'text',
            'body': 'hello-live',
            'created_at': '2026-06-21T10:00:00Z',
          },
        ]),
      );
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

    test('inbound event nested under `data` (gateway fan-out shape) also '
        'normalizes', () async {
      final socket = build(conversationId: 'conv-1');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      serverToClient.add(
        jsonEncode([
          null,
          null,
          'jeeb:chat:conv-1',
          'event',
          {
            'data': {
              'messageId': 'm-2',
              'senderId': 'other',
              'type': 'text',
              'body': 'nested',
              'sentAt': '2026-06-21T11:00:00Z',
            },
          },
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, hasLength(1));
      final payload = received.first['payload']! as Map<String, Object?>;
      expect(payload['id'], 'm-2');
      expect((payload['body']! as Map)['text'], 'nested');
      await socket.close();
    });

    test('frames on a DIFFERENT topic are ignored', () async {
      final socket = build(conversationId: 'conv-1');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      serverToClient.add(
        jsonEncode([
          null,
          null,
          'jeeb:chat:OTHER-conv',
          'message_created',
          {
            'message_id': 'm-x',
            'author_id': 'z',
            'kind': 'text',
            'body': 'nope',
          },
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isEmpty);
      await socket.close();
    });

    test('phx_reply / presence frames are ignored', () async {
      final socket = build(conversationId: 'conv-1');
      final received = <Map<String, Object?>>[];
      socket.events.listen(received.add);
      await socket.connect();

      serverToClient.add(
        jsonEncode([
          '1',
          '1',
          'jeeb:chat:conv-1',
          'phx_reply',
          {'status': 'ok'},
        ]),
      );
      serverToClient.add(
        jsonEncode([null, null, 'jeeb:chat:conv-1', 'presence_state', {}]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(received, isEmpty);
      await socket.close();
    });
  });
}

/// Minimal [WebSocketChannel] fake whose `ready` resolves immediately.
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
