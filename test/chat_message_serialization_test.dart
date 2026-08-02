// QA-PRE for JEB-1423 (T-MOB-FIX-005). Binds the codec contract that ENG

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/chat_event.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';

void main() {
  group('ChatMessage codec contract', () {
    test('round-trips with every field set (8-field identity)', () {
      final original = ChatMessage(
        clientId: 'c-1',
        conversationId: 'conv-7',
        senderId: 'user-42',
        body: 'hello',
        createdAt: DateTime.utc(2026, 5, 17, 10, 30),
        status: ChatMessageStatus.delivered,
        attempts: 2,
        serverId: 's-99',
      );
      final hydrated = ChatMessage.fromJson(original.toJson());
      // Whole-object equality covers Equatable's props (which must list all 8
      expect(hydrated, original);
      expect(hydrated.clientId, 'c-1');
      expect(hydrated.serverId, 's-99');
      expect(hydrated.conversationId, 'conv-7');
      expect(hydrated.senderId, 'user-42');
      expect(hydrated.body, 'hello');
      expect(hydrated.createdAt, DateTime.utc(2026, 5, 17, 10, 30));
      expect(hydrated.status, ChatMessageStatus.delivered);
      expect(hydrated.attempts, 2);
    });

    test('round-trips a default message (status=pending, attempts=0, '
        'serverId=null)', () {
      final original = ChatMessage(
        clientId: 'c-2',
        conversationId: 'conv',
        senderId: 'user',
        body: 'hi',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final hydrated = ChatMessage.fromJson(original.toJson());
      expect(hydrated, original);
      expect(hydrated.serverId, isNull);
      expect(hydrated.status, ChatMessageStatus.pending);
      expect(hydrated.attempts, 0);
    });

    test('toJson exposes the LEAD-pinned JSON keys', () {
      final json = ChatMessage(
        clientId: 'c-3',
        conversationId: 'conv',
        senderId: 'user',
        body: 'hi',
        createdAt: DateTime.utc(2026, 5, 17, 10, 30),
        status: ChatMessageStatus.sent,
        attempts: 1,
        serverId: 's-1',
      ).toJson();
      expect(json['clientId'], 'c-3');
      expect(json['serverId'], 's-1');
      expect(json['conversationId'], 'conv');
      expect(json['senderId'], 'user');
      expect(json['body'], 'hi');
      expect(json['createdAt'], '2026-05-17T10:30:00.000Z');
      expect(json['status'], 'sent');
      expect(json['attempts'], 1);
    });

    test('toJson serializes createdAt in UTC even when given a local TZ',
        () {
      // Build a wall-clock 2026-05-17 10:30 in a +03:00 zone; UTC equivalent
      final local = DateTime.parse('2026-05-17T10:30:00+03:00');
      final json = ChatMessage(
        clientId: 'c-tz',
        conversationId: 'conv',
        senderId: 'u',
        body: 'tz',
        createdAt: local,
      ).toJson();
      expect(json['createdAt'], '2026-05-17T07:30:00.000Z');
    });

    test('toJson emits the lowercase enum name for status', () {
      for (final s in ChatMessageStatus.values) {
        final json = ChatMessage(
          clientId: 'c',
          conversationId: 'conv',
          senderId: 'u',
          body: 'b',
          createdAt: DateTime.utc(2026, 1, 1),
          status: s,
        ).toJson();
        expect(json['status'], s.name,
            reason: 'status JSON must be the enum name (got ${json['status']} '
                'for ${s.name})');
      }
    });

    test('defaults to pending when status missing from JSON', () {
      final hydrated = ChatMessage.fromJson({
        'clientId': 'c-1',
        'conversationId': 'conv-7',
        'senderId': 'user-42',
        'body': 'hi',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(hydrated.status, ChatMessageStatus.pending);
      expect(hydrated.attempts, 0);
      expect(hydrated.serverId, isNull);
    });

    test('fromJson hydrates every status enum value', () {
      for (final s in ChatMessageStatus.values) {
        final hydrated = ChatMessage.fromJson({
          'clientId': 'c-${s.name}',
          'conversationId': 'conv',
          'senderId': 'u',
          'body': 'b',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'status': s.name,
        });
        expect(hydrated.status, s);
      }
    });
  });

  group('ChatMessage.copyWith', () {
    final base = ChatMessage(
      clientId: 'c-1',
      conversationId: 'conv-7',
      senderId: 'user-42',
      body: 'hi',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    test('preserves the clientId across status/serverId mutation', () {
      final updated = base.copyWith(
        status: ChatMessageStatus.delivered,
        serverId: 's-99',
      );
      expect(updated.clientId, 'c-1');
      expect(updated.status, ChatMessageStatus.delivered);
      expect(updated.serverId, 's-99');
    });

    test('preserves every unchanged field when only one field is updated', () {
      final updated = base.copyWith(attempts: 4);
      expect(updated.clientId, base.clientId);
      expect(updated.conversationId, base.conversationId);
      expect(updated.senderId, base.senderId);
      expect(updated.body, base.body);
      expect(updated.createdAt, base.createdAt);
      expect(updated.status, base.status);
      expect(updated.serverId, base.serverId);
      expect(updated.attempts, 4);
    });

    test('round-trip identity: copyWith with no args equals original', () {
      // Some implementations omit a no-arg copyWith — exercise field-by-field
      final round = base
          .copyWith(status: base.status)
          .copyWith(attempts: base.attempts);
      expect(round, base);
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
