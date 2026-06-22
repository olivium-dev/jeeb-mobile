import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/chat_realtime_resolver.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/data/live_realtime_chat_socket.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';

/// CHAT-CONTRACT (iter6 route fix): the gateway operates on a REAL server-minted
/// conversation_id — NOT the request id — and uses the canonical FAN-OUT routes
/// `/v1/chat/jeeb/conversations/{id}/messages` (the JeebChatMessagesController
/// BFF that persists AND live-pushes to the counterpart). send posts a NESTED
/// `body` object (the BFF's MobileSendMessageBody contract), dropping senderId.
void main() {
  group('DioChatGateway — canonical conversation routes', () {
    late _RecordingAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
    });

    test('loadHistory lists from the canonical fan-out route '
        '/v1/chat/jeeb/conversations/{conversationId}/messages and parses the '
        'mobile {items:[{id,senderId,body:{...}}]} shape', () async {
      // The fan-out BFF returns the mobile envelope key `items` and projects
      // each message as {id, senderId, body:{...nested...}}.
      adapter.onGet = (path) => _json({
            'items': [
              {
                'id': 'm-1',
                'senderId': 'me-id',
                'kind': 'text',
                'body': {'text': 'hi from me'},
                'createdAt': '2026-06-21T10:00:00Z',
              },
              {
                'id': 'm-2',
                'senderId': 'them-id',
                'kind': 'text',
                'body': {'text': 'hi back'},
                'createdAt': '2026-06-21T10:01:00Z',
              },
            ],
          });
      final gateway = DioChatGateway(dio: dio, currentUserId: 'me-id');

      final history = await gateway.loadHistory('conv-XYZ');

      // Hit the canonical fan-out conversation-id route — NOT the legacy
      // /v1/conversations/{id}/messages path (which has no live push).
      expect(
        adapter.lastGetPath,
        '/v1/chat/jeeb/conversations/conv-XYZ/messages',
      );
      expect(history, hasLength(2));
      // Server-side per-viewer (no client filtering): both items returned.
      expect(history.first.author, ChatAuthor.me);
      expect(history.last.author, ChatAuthor.them);
    });

    test('send POSTs the canonical fan-out route '
        '/v1/chat/jeeb/conversations/{conversationId}/messages with '
        '{kind, body:{text}} (nested body) and NO senderId', () async {
      adapter.onPost = (path, data) => _json({
            'id': 'srv-1',
            'senderId': 'me-id',
            'kind': 'text',
            'body': {'text': 'hello'},
            'createdAt': '2026-06-21T10:00:00Z',
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

      // The send MUST hit the fan-out route (live push), NOT the legacy
      // /v1/conversations/{id}/messages path.
      expect(
        adapter.lastPostPath,
        '/v1/chat/jeeb/conversations/conv-XYZ/messages',
      );
      final body = adapter.lastPostBody! as Map;
      expect(body['kind'], 'text');
      // Nested body object (MobileSendMessageBody contract) — the gateway
      // JSON-encodes it into chat-service's flat string and decodes it back.
      expect(body['body'], <String, Object?>{'text': 'hello'});
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

    test('connect() REMAPS the descriptor topic jeeb_conversation:{id} to the '
        'A1-bridged jeeb:chat:{id} (the only channel the REST fan-out reaches)',
        () async {
      // The gateway descriptor returns the legacy V1 topic; the socket must join
      // the V2 bridged channel or it receives ZERO live frames (proven on the
      // wire). The connect-token mint targets the realtime minter (unreachable
      // here) and degrades to '' — the socket is still built with the remapped
      // topic + the gateway ticket.
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

      final socket = await resolver.connect('conv-XYZ');

      expect(socket, isA<LiveRealtimeChatSocket>());
      final live = socket! as LiveRealtimeChatSocket;
      // Remapped to the bridged V2 topic — NOT the descriptor's V1 topic.
      expect(live.topic, 'jeeb:chat:conv-XYZ');
      // The gateway membership ticket is carried through for the V2 ticket-auth.
      expect(live.ticket, 'mint-ticket-jwt');
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
