import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

/// Regression for the s006 two-device push-tap gap: the live jeeb-gateway chat
/// push nests routing fields inside a single stringified `data` entry serialized
void main() {
  group('hoistNestedRoutingFields', () {
    test(
      'hoists conversationId + type from the exact live single-quote blob',
      () {
        final data = <String, String>{
          'data':
              "{'conversationId': '99b73825-9383-4aec-987d-169c02d96f64', "
              "'requestId': '7a5dffbd-6c05-4068-9b79-0cec377cae0f', 'type': 'chat'}",
          'title': 'New message',
          'body': 'Customer here',
        };

        hoistNestedRoutingFields(data);

        expect(data['type'], 'chat');
        expect(data['conversationId'], '99b73825-9383-4aec-987d-169c02d96f64');
        expect(data['requestId'], '7a5dffbd-6c05-4068-9b79-0cec377cae0f');
      },
    );

    test(
      'hoisted fields make a chat push resolve to /chat/<conversationId>',
      () {
        final data = <String, String>{
          'data':
              "{'conversationId': '99b73825-9383-4aec-987d-169c02d96f64', "
              "'type': 'chat'}",
          'title': 'New message',
          'body': 'hi',
        };
        hoistNestedRoutingFields(data);

        final msg = NotificationMessage(
          id: 'm1',
          category: NotificationCategory.fromKey(
            data['category'] ?? data['type'],
          ),
          title: 'New message',
          body: 'hi',
          receivedAt: DateTime(2026),
          data: data,
        );

        expect(msg.category, NotificationCategory.chat);
        expect(
          deepLinkForMessage(msg),
          '/chat/99b73825-9383-4aec-987d-169c02d96f64',
        );
      },
    );

    test('double-quote (valid JSON) nested blob also hoists', () {
      final data = <String, String>{
        'data': '{"conversationId":"abc-123","type":"chat"}',
      };
      hoistNestedRoutingFields(data);
      expect(data['type'], 'chat');
      expect(data['conversationId'], 'abc-123');
    });

    test('hoists a caseId for dotted support notification routing', () {
      final data = <String, String>{
        'data': '{"caseId":"case-42","type":"jeeb.support.replied"}',
      };
      hoistNestedRoutingFields(data);
      final message = NotificationMessage(
        id: 'support-1',
        category: NotificationCategory.fromData(data),
        title: 'Support replied',
        body: 'A reply is ready.',
        receivedAt: DateTime(2026),
        data: data,
      );

      expect(message.category, NotificationCategory.support);
      expect(deepLinkForMessage(message), '/support/tickets/case-42');
    });

    test('a real flat field is not clobbered by the nested blob', () {
      final data = <String, String>{
        'type': 'delivery',
        'data': "{'type':'chat'}",
      };
      hoistNestedRoutingFields(data);
      expect(data['type'], 'delivery');
    });

    test('no-op when there is no nested data blob (correct flat payload)', () {
      final data = <String, String>{
        'type': 'chat',
        'conversationId': 'abc-123',
      };
      hoistNestedRoutingFields(data);
      expect(data.length, 2);
      expect(data['conversationId'], 'abc-123');
    });
  });
}
