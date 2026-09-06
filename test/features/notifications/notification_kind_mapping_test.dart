import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/domain/notification_kind_mapping.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

void main() {
  const aliases = <NotificationKind, List<String>>{
    NotificationKind.chat: ['chat', 'chat_message', 'new_message'],
    NotificationKind.status: [
      'delivery',
      'delivery_status_updated',
      'cancellation_decision',
      'delivery_cancelled',
      'status',
    ],
    NotificationKind.availability: ['availability', 'auto_offline'],
    NotificationKind.requestExpired: [
      'request.try_expand_tier',
      'request.expired',
      'try_expand_tier',
      'request_expiring',
      'request_expired',
    ],
    NotificationKind.newRequest: ['new_request'],
    NotificationKind.offerAccepted: ['offer_accepted'],
    NotificationKind.offer: ['offer', 'offer_received'],
  };
  for (final entry in aliases.entries) {
    for (final wire in entry.value) {
      for (final prefix in ['', 'jeeb.']) {
        test('$prefix$wire maps to ${entry.key.name}', () {
          expect(notificationKindFromWireType('$prefix$wire'), entry.key);
          expect(
            notificationKindFromWireType(
              ' ${prefix.toUpperCase()}${wire.toUpperCase()} ',
            ),
            entry.key,
          );
        });
      }
    }
  }
  test('unaddressable kinds remain unknown', () {
    for (final wire in <String?>[
      null,
      '',
      'new-unhandled-event',
      'offer_lost',
    ]) {
      expect(notificationKindFromWireType(wire), NotificationKind.unknown);
    }
  });
}
