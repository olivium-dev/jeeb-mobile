// Every silent `return null` in the chat identity chain must now name itself.
// Behaviour is unchanged: each case still degrades to plain HTTP chat.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/chat_diagnostics.dart';
import 'package:jeeb_mobile/core/realtime/realtime_socket_policy.dart';
import 'package:jeeb_mobile/features/chat/data/chat_realtime_resolver.dart';
import 'package:jeeb_mobile/features/chat/data/gateway_chat_firebase_token_minter.dart';

Dio _dioAnswering({
  Map<String, dynamic>? body,
  int statusCode = 200,
  bool throwPlain = false,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (throwPlain) throw StateError('transport exploded');
        final response = Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        );
        if (statusCode >= 400) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
          return;
        }
        handler.resolve(response);
      },
    ),
  );
  return dio;
}

List<String> _reasonsFor(String stage) => ChatDiagnostics.events
    .where((event) => event.stage == stage)
    .map((event) => event.reason)
    .toList();

void main() {
  setUp(() {
    ChatDiagnostics.resetForTest();
    ChatDiagnostics.sink = (_) {};
  });
  tearDown(ChatDiagnostics.resetForTest);

  group('mint', () {
    test('a 200 with no token records mint/no_token and still returns null',
        () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(body: <String, dynamic>{}),
      );
      expect(await minter.mintCustomToken(), isNull);
      expect(_reasonsFor(ChatDiagStage.mint), <String>['no_token']);
      expect(ChatDiagnostics.events.single.status, 200);
    });

    test('an HTTP error records the status that caused it', () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(statusCode: 503),
      );
      expect(await minter.mintCustomToken(), isNull);
      expect(_reasonsFor(ChatDiagStage.mint).single, startsWith('http_'));
      expect(ChatDiagnostics.events.single.status, 503);
    });

    test('a non-Dio throw is recorded rather than swallowed', () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(throwPlain: true),
      );
      expect(await minter.mintCustomToken(), isNull);
      expect(_reasonsFor(ChatDiagStage.mint), isNotEmpty);
    });

    test('a successful mint records nothing', () async {
      final minter = GatewayChatFirebaseTokenMinter(
        dio: _dioAnswering(body: <String, dynamic>{'token': 'jwt'}),
      );
      expect(await minter.mintCustomToken(), 'jwt');
      expect(ChatDiagnostics.events, isEmpty);
    });
  });

  group('descriptor', () {
    const conversationId = 'conversation-42';
    const currentUserId = 'user-1';

    ChatRealtimeResolver resolverOver(Dio dio) => ChatRealtimeResolver(
      dio: dio,
      currentUserId: currentUserId,
      socketPolicy: const RealtimeSocketPolicy(
        configuredUrl: 'wss://app.jeeb.fds-1.com/socket/websocket',
      ),
    );

    test('an HTTP failure records descriptor/http_* with the status', () async {
      final resolver = resolverOver(_dioAnswering(statusCode: 403));
      expect(await resolver.resolve(conversationId), isNull);
      expect(_reasonsFor(ChatDiagStage.descriptor).single, startsWith('http_'));
      expect(ChatDiagnostics.events.single.status, 403);
      expect(ChatDiagnostics.events.single.conversationId, conversationId);
    });

    test('a body with no topic records descriptor/no_topic', () async {
      final resolver = resolverOver(
        _dioAnswering(body: <String, dynamic>{'viewerId': currentUserId}),
      );
      expect(await resolver.resolve(conversationId), isNull);
      expect(_reasonsFor(ChatDiagStage.descriptor), <String>['no_topic']);
    });

    test('a topic that does not match the conversation records the refusal',
        () async {
      final resolver = resolverOver(
        _dioAnswering(
          body: <String, dynamic>{
            'conversationId': conversationId,
            'viewerId': currentUserId,
            'topic': 'jeeb_conversation:$conversationId',
            'roleInConvo': 'client',
            'token': 't',
            'ticket': 'k',
          },
        ),
      );
      expect(await resolver.resolve(conversationId), isNull);
      expect(_reasonsFor(ChatDiagStage.descriptor), <String>['binding_refused']);
    });

    test('a viewer id that is not this user records the refusal', () async {
      final resolver = resolverOver(
        _dioAnswering(
          body: <String, dynamic>{
            'conversationId': conversationId,
            'viewerId': 'someone-else',
            'topic': 'jeeb:chat:$conversationId',
            'roleInConvo': 'client',
            'token': 't',
            'ticket': 'k',
          },
        ),
      );
      expect(await resolver.resolve(conversationId), isNull);
      expect(_reasonsFor(ChatDiagStage.descriptor), <String>['binding_refused']);
    });

    test('a good descriptor records nothing', () async {
      final resolver = resolverOver(
        _dioAnswering(
          body: <String, dynamic>{
            'conversationId': conversationId,
            'viewerId': currentUserId,
            'topic': 'jeeb:chat:$conversationId',
            'roleInConvo': 'client',
            'token': 't',
            'ticket': 'k',
          },
        ),
      );
      expect(await resolver.resolve(conversationId), isNotNull);
      expect(ChatDiagnostics.events, isEmpty);
    });
  });

  group('socket', () {
    const conversationId = 'conversation-42';
    const currentUserId = 'user-1';

    Map<String, dynamic> goodDescriptor({String token = 't'}) =>
        <String, dynamic>{
          'conversationId': conversationId,
          'viewerId': currentUserId,
          'topic': 'jeeb:chat:$conversationId',
          'roleInConvo': 'client',
          'token': token,
          'ticket': 'k',
        };

    // A blank connect token is refused one stage earlier, by `_bindingAllowed`,
    // so `connect` reports the descriptor refusal rather than a socket one.
    test('a blank connect token is refused and named at the descriptor stage',
        () async {
      final resolver = ChatRealtimeResolver(
        dio: _dioAnswering(body: goodDescriptor(token: '')),
        currentUserId: currentUserId,
        socketPolicy: const RealtimeSocketPolicy(
          configuredUrl: 'wss://app.jeeb.fds-1.com/socket/websocket',
        ),
      );
      expect(await resolver.connect(conversationId), isNull);
      expect(_reasonsFor(ChatDiagStage.descriptor), <String>['binding_refused']);
      expect(_reasonsFor(ChatDiagStage.socket), isEmpty);
    });

    test('an unset JEEB_REALTIME_SOCKET_URL names the compile-time gap',
        () async {
      final resolver = ChatRealtimeResolver(
        dio: _dioAnswering(body: goodDescriptor()),
        currentUserId: currentUserId,
        socketPolicy: const RealtimeSocketPolicy(configuredUrl: ''),
      );
      expect(await resolver.connect(conversationId), isNull);
      expect(
        _reasonsFor(ChatDiagStage.socket),
        <String>['no_configured_socket_url'],
      );
    });
  });
}
