import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/chat_realtime_resolver.dart';
import 'package:jeeb_mobile/features/chat/data/live_realtime_chat_socket.dart';

void main() {
  const conversationId = 'conversation-42';

  Dio dioAnswering(Map<String, dynamic> body) {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: body,
          ),
        ),
      ),
    );
    return dio;
  }

  Map<String, dynamic> descriptor({
    String ticket = 'membership-ticket',
    String token = 'conversation-scoped-guardian-token',
    Object? socketUrl = 'wss://realtime.jeeb.test/socket/websocket',
  }) => <String, dynamic>{
    'conversationId': conversationId,
    'topic': 'jeeb:chat:$conversationId',
    'roleInConvo': 'client',
    'ticket': ticket,
    'token': token,
    'socketUrl': socketUrl,
  };

  test(
    'uses the gateway-issued membership and scoped connect credentials',
    () async {
      final resolver = ChatRealtimeResolver(
        dio: dioAnswering(descriptor()),
        currentUserId: 'user-1',
      );

      final socket = await resolver.connect(conversationId);

      expect(socket, isA<LiveRealtimeChatSocket>());
      final live = socket! as LiveRealtimeChatSocket;
      expect(live.ticket, 'membership-ticket');
      expect(live.connectToken, 'conversation-scoped-guardian-token');
      expect(live.topic, 'jeeb:chat:$conversationId');
    },
  );

  for (final missing in <String>['ticket', 'token', 'socket']) {
    test('fails closed when the gateway descriptor has no $missing', () async {
      final body = descriptor(
        ticket: missing == 'ticket' ? '' : 'membership-ticket',
        token: missing == 'token' ? '' : 'conversation-scoped-guardian-token',
        socketUrl: missing == 'socket'
            ? null
            : 'wss://realtime.jeeb.test/socket/websocket',
      );
      final resolver = ChatRealtimeResolver(
        dio: dioAnswering(body),
        currentUserId: 'user-1',
      );

      expect(await resolver.connect(conversationId), isNull);
    });
  }

  test('release code has no direct open or wildcard realtime token mint', () {
    final source = File(
      'lib/features/chat/data/chat_realtime_resolver.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('/api/auth/token')));
    expect(source, isNot(contains("<String>['*']")));
    expect(source, isNot(contains('Dio().post')));
    final gateway = File(
      'lib/features/chat/data/dio_chat_gateway.dart',
    ).readAsStringSync();
    expect(gateway, isNot(contains('MockGatewayClient.webSocketUrl')));
  });
}
