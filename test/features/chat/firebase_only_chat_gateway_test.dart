import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/dio_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/data/realtime_chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_realtime_source.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';

class _OwnerRealtime implements ChatRealtimeSource {
  final events = StreamController<ChatEvent>.broadcast();
  int subscriptions = 0;

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    subscriptions++;
    return events.stream;
  }

  @override
  Future<void> dispose() => events.close();
}

void main() {
  test(
    'HTTP chat never requests descriptors; Firebase and accept events survive',
    () async {
      final paths = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: options.path.endsWith('/accept')
                    ? <String, dynamic>{'deliveryId': 'delivery-1'}
                    : options.method == 'POST'
                    ? <String, dynamic>{'id': 'server-1'}
                    : <String, dynamic>{'messages': <dynamic>[]},
              ),
            );
          },
        ),
      );
      final http = DioChatGateway(dio: dio, currentUserId: 'actor-1');
      final realtime = _OwnerRealtime();
      final gateway = RealtimeChatGateway(inner: http, realtime: realtime);
      final received = <ChatEvent>[];
      final subscription = gateway
          .subscribe('conversation-1')
          .listen(received.add);

      await Future<void>.delayed(Duration.zero);
      expect(
        paths,
        isEmpty,
        reason: 'subscribing has no HTTP/Phoenix bootstrap',
      );
      final message = DeliveryChatMessage.text(
        id: 'message-1',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026),
        status: MessageStatus.sent,
        text: 'owner Firestore message',
      );
      realtime.events.add(IncomingMessage(message));
      await gateway.loadHistory('conversation-1');
      await gateway.send('conversation-1', message);
      await gateway.acceptOffer('conversation-1', 'offer-1');
      await Future<void>.delayed(Duration.zero);

      expect(realtime.subscriptions, 1);
      expect(
        received.whereType<IncomingMessage>().single.message.id,
        'message-1',
      );
      expect(
        received.whereType<PhaseChanged>().single.phase,
        ConversationPhase.accepted,
      );
      expect(paths, <String>[
        '/v1/conversations/conversation-1/messages',
        '/v1/conversations/conversation-1/messages',
        '/v1/offers/offer-1/accept',
      ]);
      await subscription.cancel();
      await gateway.dispose();
      await http.dispose();
      dio.close();
    },
  );

  test(
    'production chat wiring cannot reintroduce a Phoenix descriptor leg',
    () {
      final http = File(
        'lib/features/chat/data/dio_chat_gateway.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/features/deep_link_targets/chat_detail_screen.dart',
      ).readAsStringSync();
      for (final source in <String>[http, screen]) {
        expect(source, isNot(contains('ChatRealtimeResolver')));
        expect(source, isNot(contains('socketFactory')));
        expect(source, isNot(contains('socketBaseUri')));
        expect(source, isNot(contains('/v1/realtime/')));
        expect(source, isNot(contains('phx_join')));
      }
      expect(screen, contains('FirestoreChatRealtimeSource('));
      expect(screen, contains('FirebaseCustomTokenIdentity('));
    },
  );
}
