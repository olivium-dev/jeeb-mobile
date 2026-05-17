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

    test('kyc routes to /profile/kyc regardless of payload', () {
      final path = deepLinkForMessage(_msg(category: NotificationCategory.kyc));
      expect(path, '/profile/kyc');
    });

    test('rating routes to /orders/<id>/rate', () {
      final path = deepLinkForMessage(_msg(
        category: NotificationCategory.rating,
        data: const {'delivery_id': 'd-77'},
      ));
      expect(path, '/orders/d-77/rate');
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

    test('unknown / null fall back to other', () {
      expect(NotificationCategory.fromKey(null), NotificationCategory.other);
      expect(NotificationCategory.fromKey('marketing'),
          NotificationCategory.other);
    });
  });
}
