import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/chat_realtime_resolver.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';

/// CHAT-CONTRACT (iter6): the gateway operates on a REAL server-minted
/// conversation_id — NOT the request id — and uses the canonical
/// `/v1/conversations/{id}/messages` routes, dropping senderId from the body.
void main() {
  group('DioChatGateway — canonical conversation routes', () {
    late _RecordingAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
    });

    test('loadHistory lists from /v1/conversations/{conversationId}/messages '
        'and parses the canonical {messages:[{message_id,author_id,...}]} shape',
        () async {
      adapter.onGet = (path) => _json({
            'messages': [
              {
                'message_id': 'm-1',
                'author_id': 'me-id',
                'kind': 'text',
                'body': 'hi from me',
                'created_at': '2026-06-21T10:00:00Z',
              },
              {
                'message_id': 'm-2',
                'author_id': 'them-id',
                'kind': 'text',
                'body': 'hi back',
                'created_at': '2026-06-21T10:01:00Z',
              },
            ],
          });
      final gateway = DioChatGateway(dio: dio, currentUserId: 'me-id');

      final history = await gateway.loadHistory('conv-XYZ');

      // Hit the conversation-id route, NOT the request id, NOT the legacy
      // /v1/chat/jeeb/conversations/{id}/messages path.
      expect(adapter.lastGetPath, '/v1/conversations/conv-XYZ/messages');
      expect(history, hasLength(2));
      // Server-side per-viewer (no client filtering): both items returned.
      expect(history.first.author, ChatAuthor.me);
      expect(history.last.author, ChatAuthor.them);
    });

    test('send POSTs /v1/conversations/{conversationId}/messages with '
        '{kind, audience, body} and NO senderId', () async {
      adapter.onPost = (path, data) => _json({
            'message_id': 'srv-1',
            'author_id': 'me-id',
            'kind': 'text',
            'body': 'hello',
            'created_at': '2026-06-21T10:00:00Z',
          });
      final gateway = DioChatGateway(dio: dio, currentUserId: 'me-id');

      final ack = await gateway.send(
        'conv-XYZ',
        DeliveryChatMessage.text(
          id: 'local-1',
          author: ChatAuthor.me,
          sentAt: DateTime(2026, 6, 21),
          status: MessageStatus.sending,
          text: 'hello',
        ),
      );

      expect(adapter.lastPostPath, '/v1/conversations/conv-XYZ/messages');
      final body = adapter.lastPostBody! as Map;
      expect(body['kind'], 'text');
      expect(body['body'], 'hello');
      expect(body['audience'], 'all');
      // The author is stamped from the bearer server-side — senderId is DROPPED.
      expect(body.containsKey('senderId'), isFalse);
      expect(ack.status, MessageStatus.sent);
    });
  });

  group('ChatRealtimeResolver — per-conversation realtime descriptor', () {
    test('resolves /v1/realtime/jeeb:chat:{conversationId} into a socket bound '
        'to the per-conversation topic + gateway ticket', () async {
      final adapter = _RecordingAdapter()
        ..onGet = (path) => _json({
              'conversationId': 'conv-XYZ',
              'topic': 'jeeb_conversation:conv-XYZ',
              'roleInConvo': 'client',
              'ticket': 'mint-ticket-jwt',
            });
      final dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;

      final resolver = ChatRealtimeResolver(
        dio: dio,
        currentUserId: 'me-id',
        socketBaseUri: Uri.parse('ws://realtime.test/socket/websocket'),
      );

      final descriptor = await resolver.resolve('conv-XYZ');

      expect(adapter.lastGetPath, '/v1/realtime/jeeb:chat:conv-XYZ');
      expect(descriptor, isNotNull);
      expect(descriptor!.topic, 'jeeb_conversation:conv-XYZ');
      expect(descriptor.ticket, 'mint-ticket-jwt');
    });

    test('a non-member 403 resolves to null (degrade to HTTP history)',
        () async {
      final adapter = _RecordingAdapter()..getStatus = 403;
      final dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
      final resolver = ChatRealtimeResolver(dio: dio, currentUserId: 'me-id');

      final socket = await resolver.connect('conv-XYZ');
      expect(socket, isNull);
    });
  });

  group('DioChatGateway.subscribe — wiring', () {
    test('subscribe builds the socket via the injected factory and joins '
        '(degrade-don\'t-fail when the resolver yields none)', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
      final fakeSocket = _FakeSocket();
      final gateway = DioChatGateway(
        dio: dio,
        currentUserId: 'me-id',
        socketFactory: (_) => fakeSocket,
      );

      gateway.subscribe('conv-XYZ');
      // Let the async connect+join run.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(fakeSocket.connected, isTrue);
      expect(fakeSocket.joinSent, isTrue);
    });
  });
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  ResponseBody Function(String path)? onGet;
  ResponseBody Function(String path, Object? data)? onPost;
  int getStatus = 200;

  String? lastGetPath;
  String? lastPostPath;
  Object? lastPostBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      lastGetPath = options.path;
      if (getStatus != 200) {
        return ResponseBody.fromString('{}', getStatus, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      }
      return onGet?.call(options.path) ?? _json(const {});
    }
    lastPostPath = options.path;
    lastPostBody = options.data;
    return onPost?.call(options.path, options.data) ?? _json(const {});
  }
}

class _FakeSocket implements ChatSocket {
  bool connected = false;
  bool joinSent = false;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  @override
  Stream<Map<String, Object?>> get events => _events.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Future<void> connect() async => connected = true;
  @override
  void send(Map<String, Object?> envelope) {
    if (envelope['event'] == 'phx_join') joinSent = true;
  }

  @override
  Future<void> close() async {
    await _events.close();
    await _errors.close();
  }
}
