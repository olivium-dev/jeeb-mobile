import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

NotificationMessage _msg({
  required NotificationCategory category,
  Map<String, String> data = const {},
}) {
  return NotificationMessage(
    id: 'm-1',
    category: category,
    title: 't',
    body: 'b',
    receivedAt: DateTime.utc(2026, 5, 17),
    data: data,
  );
}

void main() {
  group('deepLinkForMessage', () {
    test('delivery routes to /orders/<delivery_id>', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.delivery,
        data: const {'delivery_id': 'd-42'},
      ));
      expect(path, '/orders/d-42');
    });

    test('delivery falls back to order_id when delivery_id is missing', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.delivery,
        data: const {'order_id': 'o-9'},
      ));
      expect(path, '/orders/o-9');
    });

    test('delivery without any id returns null (no crash)', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.delivery,
      ));
      expect(path, isNull);
    });

    test('chat routes to /chat/<id>', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.chat,
        data: const {'chat_id': 'c-1'},
      ));
      expect(path, '/chat/c-1');
    });

    test('chat routes via jeeb-gateway camelCase conversationId', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.chat,
        data: const {'conversationId': 'conv-7'},
      ));
      expect(path, '/chat/conv-7');
    });

    test('chat prefers conversationId over legacy keys', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.chat,
        data: const {
          'conversationId': 'conv-9',
          'conversation_id': 'snake-9',
          'chat_id': 'legacy-9',
        },
      ));
      expect(path, '/chat/conv-9');
    });

    test('chat without any id returns null (no crash)', () {
      final path = deepLinkForMessage(_msg(category: NotificationCategory.chat));
      expect(path, isNull);
    });

    test('kyc routes to /profile/kyc regardless of payload', () {
      final path = deepLinkForMessage(_msg(category: NotificationCategory.kyc));
      expect(path, '/profile/kyc');
    });

    test('delivery routes via jeeb-gateway camelCase deliveryId', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.delivery,
        data: const {'deliveryId': 'd-100', 'status': 'PickedUp'},
      ));
      expect(path, '/orders/d-100');
    });

    test('delivery (offer/accept push) routes via requestId', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.delivery,
        data: const {'requestId': 'r-55', 'offerId': 'o-1'},
      ));
      expect(path, '/orders/r-55');
    });

    test('rating routes to /orders/<id>/rate', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.rating,
        data: const {'delivery_id': 'd-77'},
      ));
      expect(path, '/orders/d-77/rate');
    });

    test('rating routes via camelCase deliveryId', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.rating,
        data: const {'deliveryId': 'd-88'},
      ));
      expect(path, '/orders/d-88/rate');
    });

    test('settings routes to /settings/notifications', () {
      final path = deepLinkForMessage(
        _msg(category: NotificationCategory.settings),
      );
      expect(path, '/settings/notifications');
    });

    test('other category returns null (banner with no destination)', () {
      final path = deepLinkForMessage(_msg(category: NotificationCategory.other));
      expect(path, isNull);
    });
  });

  group('NotificationCategory.fromKey', () {
    test('maps known keys', () {
      expect(NotificationCategory.fromKey('delivery'),
          NotificationCategory.delivery);
      expect(NotificationCategory.fromKey('chat'), NotificationCategory.chat);
      expect(NotificationCategory.fromKey('kyc'), NotificationCategory.kyc);
      expect(NotificationCategory.fromKey('rating'),
          NotificationCategory.rating);
      expect(NotificationCategory.fromKey('settings'),
          NotificationCategory.settings);
    });

    test('maps jeeb-gateway `type` wire values to the order surface', () {
      // EventPushNotifier emits these on its `type` key.
      expect(NotificationCategory.fromKey('offer'),
          NotificationCategory.delivery);
      expect(NotificationCategory.fromKey('accept'),
          NotificationCategory.delivery);
    });

    test('unknown / null fall back to other', () {
      expect(NotificationCategory.fromKey(null), NotificationCategory.other);
      expect(NotificationCategory.fromKey('marketing'),
          NotificationCategory.other);
    });
  });

  group('NotificationCategory.fromData', () {
    test('resolves a chat push from the gateway `type` key (no category)', () {
      expect(
        NotificationCategory.fromData(const {'type': 'chat'}),
        NotificationCategory.chat,
      );
    });

    test('resolves a delivery push from `type`', () {
      expect(
        NotificationCategory.fromData(const {'type': 'delivery'}),
        NotificationCategory.delivery,
      );
    });

    test('explicit category takes precedence over type', () {
      expect(
        NotificationCategory.fromData(
          const {'category': 'chat', 'type': 'delivery'},
        ),
        NotificationCategory.chat,
      );
    });

    test('empty / unknown data falls back to other', () {
      expect(
        NotificationCategory.fromData(const {}),
        NotificationCategory.other,
      );
      expect(
        NotificationCategory.fromData(const {'type': 'mystery'}),
        NotificationCategory.other,
      );
    });
  });

  // End-to-end against the EXACT data map jeeb-gateway's iter6
  // JeebChatMessagesController fan-out emits for a chat-send push. This is the
  // acceptance-relevant chain: a real chat push must categorise as chat AND
  // resolve to the original conversation thread on tap. Asserts on the real
  // shape (camelCase `conversationId` + `type`), not an id-only stand-in.
  group('jeeb-gateway chat push end-to-end', () {
    test('categorises + deep-links to the original thread', () {
      const gatewayChatData = <String, String>{
        'type': 'chat',
        'conversationId': 'conv-abc',
        'messageId': 'msg-1',
        'senderId': 'user-2',
        // The push service flattens title/body into data as well.
        'title': 'New message',
        'body': 'Hi there',
      };

      final category = NotificationCategory.fromData(gatewayChatData);
      expect(category, NotificationCategory.chat);

      final message = _msg(category: category, data: gatewayChatData);
      expect(deepLinkForMessage(message), '/chat/conv-abc');
    });
  });
}
