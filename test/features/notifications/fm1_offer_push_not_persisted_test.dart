import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/data/shared_prefs_local_push_inbox.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

const _offerPushTypes = <String>[
  'jeeb.offer_received',
  'jeeb.offer_accepted',
  'offer',
];

NotificationMessage _foregroundMessage(String type) {
  final data = <String, String>{'type': type, 'requestId': 'request-$type'};
  return NotificationMessage(
    id: 'foreground-$type',
    category: NotificationCategory.fromData(data),
    title: 'Offer update',
    body: 'Offer body',
    receivedAt: DateTime.utc(2026, 7, 26),
    data: data,
  );
}

RemoteMessage _backgroundMessage(String type) => RemoteMessage(
  messageId: 'background-$type',
  data: <String, dynamic>{'type': type, 'requestId': 'request-$type'},
  notification: const RemoteNotification(
    title: 'Offer update',
    body: 'Offer body',
  ),
);

Future<void> _deliverForeground(
  String type,
  SharedPrefsLocalPushInbox inbox,
) async {
  final transport = FakePushTransport();
  final badge = BadgeCountCubit();
  final handler = PushNotificationHandler(
    transport: transport,
    badgeCount: badge,
    localInbox: inbox,
  );

  try {
    final handled = handler.stream.firstWhere(
      (state) =>
          state.history.any((message) => message.id == 'foreground-$type'),
    );
    transport.emitForeground(_foregroundMessage(type));
    await handled;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  } finally {
    await handler.close();
    await badge.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FM1-authored offer push local persistence', () {
    late SharedPrefsLocalPushInbox inbox;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      inbox = SharedPrefsLocalPushInbox(
        prefs: await SharedPreferences.getInstance(),
      );
    });

    group('foreground handler path', () {
      for (final type in _offerPushTypes) {
        test('data type $type leaves LocalPushInbox empty', () async {
          await _deliverForeground(type, inbox);

          expect(
            await inbox.readAll(),
            isEmpty,
            reason: '$type is server-row-only and must not create a local row',
          );
        });
      }

      test('CONTROL data type new_request is persisted', () async {
        await _deliverForeground(kNewRequestPushType, inbox);

        final records = await inbox.readAll();
        expect(records, hasLength(1));
        expect(records.single.type, kNewRequestPushType);
      });
    });

    group('background/terminated transport path', () {
      for (final type in _offerPushTypes) {
        test('data type $type leaves LocalPushInbox empty', () async {
          await firebaseMessagingBackgroundHandler(_backgroundMessage(type));

          expect(
            await inbox.readAll(),
            isEmpty,
            reason: '$type is server-row-only and must not create a local row',
          );
        });
      }

      test('CONTROL data type new_request is persisted', () async {
        await firebaseMessagingBackgroundHandler(
          _backgroundMessage(kNewRequestPushType),
        );

        final records = await inbox.readAll();
        expect(records, hasLength(1));
        expect(records.single.type, kNewRequestPushType);
      });
    });
  });
}
