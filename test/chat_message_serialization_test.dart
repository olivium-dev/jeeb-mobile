import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/chat_event.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('round-trips through toJson/fromJson', () {
      final original = ChatMessage(
        clientId: 'c-1',
        conversationId: 'conv-7',
        senderId: 'user-42',
        body: 'hello',
        createdAt: DateTime.utc(2026, 5, 17, 10, 30),
        status: ChatMessageStatus.pending,
        attempts: 2,
      );
      final hydrated = ChatMessage.fromJson(original.toJson());
      expect(hydrated, original);
    });

    test('defaults to pending when status missing', () {
      final hydrated = ChatMessage.fromJson({
        'clientId': 'c-1',
        'conversationId': 'conv-7',
        'senderId': 'user-42',
        'body': 'hi',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(hydrated.status, ChatMessageStatus.pending);
      expect(hydrated.attempts, 0);
    });

    test('copyWith preserves the clientId', () {
      final message = ChatMessage(
        clientId: 'c-1',
        conversationId: 'conv-7',
        senderId: 'user-42',
        body: 'hi',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final updated = message.copyWith(
        status: ChatMessageStatus.delivered,
        serverId: 's-99',
      );
      expect(updated.clientId, 'c-1');
      expect(updated.status, ChatMessageStatus.delivered);
      expect(updated.serverId, 's-99');
    });
  });

  group('ChatEvent.fromJson', () {
    test('decodes a message frame', () {
      final event = ChatEvent.fromJson({
        'type': 'message',
        'message': {
          'clientId': 'c-1',
          'conversationId': 'conv-7',
          'senderId': 'user-1',
          'body': 'hi',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
      });
      expect(event, isA<MessageReceivedEvent>());
      expect((event as MessageReceivedEvent).message.body, 'hi');
    });

    test('decodes an ack frame and maps status', () {
      final event = ChatEvent.fromJson({
        'type': 'ack',
        'clientId': 'c-1',
        'serverId': 's-99',
        'status': 'delivered',
      });
      expect(event, isA<MessageAckEvent>());
      final ack = event as MessageAckEvent;
      expect(ack.clientId, 'c-1');
      expect(ack.serverId, 's-99');
      expect(ack.status, ChatMessageStatus.delivered);
    });

    test('decodes a typing frame', () {
      final event = ChatEvent.fromJson({
        'type': 'typing',
        'conversationId': 'conv-7',
        'senderId': 'user-99',
        'isTyping': true,
      });
      expect(event, isA<TypingEvent>());
      final typing = event as TypingEvent;
      expect(typing.senderId, 'user-99');
      expect(typing.isTyping, isTrue);
    });

    test('unknown types do not blow up', () {
      final event = ChatEvent.fromJson({'type': 'banana'});
      expect(event, isA<UnknownEvent>());
      expect((event as UnknownEvent).rawType, 'banana');
    });
  });
}
