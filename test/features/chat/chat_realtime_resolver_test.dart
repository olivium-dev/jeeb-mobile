import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/realtime/realtime_socket_policy.dart';
import 'package:jeeb_mobile/features/chat/data/chat_realtime_resolver.dart';
import 'package:jeeb_mobile/features/chat/data/live_realtime_chat_socket.dart';

void main() {
  const conversationId = 'conversation-42';
  const currentUserId = 'user-1';
  const canonicalTopic = 'jeeb:chat:$conversationId';
  const canonicalSocketUrl = 'wss://app.jeeb.fds-1.com/socket/websocket';
  const socketPolicy = RealtimeSocketPolicy(configuredUrl: canonicalSocketUrl);

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
    Object? conversationIdValue = conversationId,
    Object? viewerIdValue = currentUserId,
    Object? topicValue = canonicalTopic,
    Object? roleValue = 'client',
    String connectToken = 'guardian-connect-token',
    String ticket = 'membership-ticket',
  }) => <String, dynamic>{
    'conversationId': conversationIdValue,
    'viewerId': viewerIdValue,
    'topic': topicValue,
    'roleInConvo': roleValue,
    'token': connectToken,
    'ticket': ticket,
  };

  test(
    'uses gateway actor, role, topic, connect token, and membership ticket',
    () async {
      final resolver = ChatRealtimeResolver(
        dio: dioAnswering(descriptor()),
        currentUserId: currentUserId,
        socketPolicy: socketPolicy,
      );

      final socket = await resolver.connect(conversationId);

      expect(socket, isA<LiveRealtimeChatSocket>());
      final live = socket! as LiveRealtimeChatSocket;
      expect(live.connectToken, 'guardian-connect-token');
      expect(live.ticket, 'membership-ticket');
      expect(live.topic, canonicalTopic);
    },
  );

  for (final missing in <String>['token', 'ticket', 'socket config']) {
    test('fails closed when the gateway descriptor has no $missing', () async {
      final body = descriptor(
        connectToken: missing == 'token' ? '' : 'guardian-connect-token',
        ticket: missing == 'ticket' ? '' : 'membership-ticket',
      );
      final resolver = ChatRealtimeResolver(
        dio: dioAnswering(body),
        currentUserId: currentUserId,
        socketPolicy: missing == 'socket config'
            ? const RealtimeSocketPolicy(configuredUrl: '')
            : socketPolicy,
      );

      expect(await resolver.connect(conversationId), isNull);
    });
  }

  group('production descriptor binding rejects before socket creation', () {
    Future<void> expectRejected(
      Map<String, dynamic> body, {
      Uri? socketBaseUri,
    }) async {
      var factoryCalls = 0;
      final resolver = ChatRealtimeResolver(
        dio: dioAnswering(body),
        currentUserId: currentUserId,
        socketBaseUri: socketBaseUri,
        socketPolicy: socketPolicy,
        socketFactory: (_, _, _) {
          factoryCalls++;
          throw StateError('invalid descriptor reached socket creation');
        },
      );

      expect(await resolver.connect(conversationId), isNull);
      expect(factoryCalls, 0);
    }

    test('rejects a descriptor bound to another conversation', () {
      return expectRejected(
        descriptor(conversationIdValue: 'conversation-evil'),
      );
    });

    test('rejects a topic bound to another conversation', () {
      return expectRejected(
        descriptor(topicValue: 'jeeb:chat:conversation-evil'),
      );
    });

    test('rejects the legacy jeeb_conversation topic', () {
      return expectRejected(
        descriptor(topicValue: 'jeeb_conversation:$conversationId'),
      );
    });

    test('rejects a missing returned conversation id', () {
      final body = descriptor()..remove('conversationId');
      return expectRejected(body);
    });

    test('rejects a descriptor bound to another viewer', () {
      return expectRejected(descriptor(viewerIdValue: 'user-evil'));
    });

    test('rejects a missing viewer id', () {
      final body = descriptor()..remove('viewerId');
      return expectRejected(body);
    });

    test('rejects ticket-only credentials before socket creation', () {
      return expectRejected(
        descriptor(connectToken: '', ticket: 'guardian-token-in-join-only'),
      );
    });

    test('rejects token-only credentials before socket creation', () {
      return expectRejected(
        descriptor(connectToken: 'guardian-connect-token', ticket: ''),
      );
    });

    for (final field in <String>['token', 'ticket']) {
      test('rejects a blank $field before socket creation', () {
        return expectRejected(
          descriptor(
            connectToken: field == 'token' ? '   ' : 'guardian-connect-token',
            ticket: field == 'ticket' ? '   ' : 'membership-ticket',
          ),
        );
      });
    }

    for (final role in <Object?>['admin', '', null]) {
      test('rejects invalid role $role', () {
        return expectRejected(descriptor(roleValue: role));
      });
    }
  });

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
