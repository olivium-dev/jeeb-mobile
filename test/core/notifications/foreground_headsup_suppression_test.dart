// b02 fg-suppression — the TRANSPORT-level early return.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/active_chat_thread.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

FirebaseMessagingTransport _transport(
  Set<String> openThreads, {
  Set<String> Function()? roles,
}) =>
    FirebaseMessagingTransport(
      messaging: _MockMessaging(),
      localNotifications: _MockLocalNotifications(),
      openChatThreadIds: () => openThreads,
      localRoles: roles,
    );

RemoteMessage _msg(String id, Map<String, String> data) =>
    RemoteMessage(messageId: id, data: data);

void main() {
  test('a SILENT push is suppressed before the render path', () async {
    final transport = _transport(const <String>{});
    transport.debugHandleForeground(
      _msg('m-silent', const <String, String>{
        'type': 'new_request',
        'requestId': 'req-1',
        'silent': 'True',
      }),
    );
    expect(transport.debugForegroundShownIds, isEmpty);
    await transport.dispose();
  });

  test('a chat push for the OPEN thread is suppressed', () async {
    final transport = _transport(const <String>{'conv-1'});
    transport.debugHandleForeground(
      _msg('m-open', const <String, String>{
        'type': 'chat',
        'conversationId': 'conv-1',
      }),
    );
    expect(transport.debugForegroundShownIds, isEmpty);
    await transport.dispose();
  });

  test(
    'a chat push for a DIFFERENT thread reaches the render path (foreground)',
    () async {
      final transport = _transport(const <String>{'conv-1'});
      transport.debugHandleForeground(
        _msg('m-other', const <String, String>{
          'type': 'chat',
          'conversationId': 'conv-2',
        }),
      );
      expect(transport.debugForegroundShownIds, <String>{'m-other'});
      await transport.dispose();
    },
  );

  test(
    'NEGATIVE CONTROL: a normal visible push still reaches the render path',
    () async {
      // Without this, "everything is suppressed" would pass every test above.
      final transport = _transport(const <String>{'conv-1'});
      transport.debugHandleForeground(
        _msg('m-visible', const <String, String>{
          'type': 'kyc_status',
          'title': 'KYC approved',
        }),
      );
      expect(transport.debugForegroundShownIds, <String>{'m-visible'});
      await transport.dispose();
    },
  );

  test(
    'a suppressed push is STILL published on the foreground stream '
    '(the refresh that a silent push exists for)',
    () async {
      final transport = _transport(const <String>{});
      final seen = <NotificationMessage>[];
      final sub = transport.onForegroundMessage.listen(seen.add);
      transport.debugHandleForeground(
        _msg('m-refresh', const <String, String>{
          'type': 'new_request',
          'requestId': 'req-1',
          'silent': 'true',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.map((m) => m.id), <String>['m-refresh']);
      expect(seen.single.category, NotificationCategory.newRequest);
      await sub.cancel();
      await transport.dispose();
    },
  );

  const driverPush = <String, String>{
    'type': 'new_request',
    'requestId': 'req-1',
    'audience_role': 'driver',
  };

  test(
    'P1 audience gate: client-only roles + audience_role=driver ⇒ NO heads-up, '
    'stream event STILL emitted',
    () async {
      final transport = _transport(
        const <String>{},
        roles: () => const {'client'},
      );
      final seen = <NotificationMessage>[];
      final sub = transport.onForegroundMessage.listen(seen.add);
      transport.debugHandleForeground(_msg('m-aud', driverPush));
      await Future<void>.delayed(Duration.zero);
      expect(transport.debugForegroundShownIds, isEmpty);
      expect(
        seen.map((m) => m.id),
        <String>['m-aud'],
        reason: 'display-only gate; downstream consumers still get the event',
      );
      await sub.cancel();
      await transport.dispose();
    },
  );

  test('a dual-role jeeber still gets the driver heads-up', () async {
    final transport = _transport(
      const <String>{},
      roles: () => const {'client', 'jeeber'},
    );
    transport.debugHandleForeground(_msg('m-dual', driverPush));
    expect(transport.debugForegroundShownIds, <String>{'m-dual'});
    await transport.dispose();
  });

  test('NO roles resolver injected ⇒ audience_role ignored (unchanged)',
      () async {
    final transport = _transport(const <String>{});
    transport.debugHandleForeground(_msg('m-noresolver', driverPush));
    expect(transport.debugForegroundShownIds, <String>{'m-noresolver'});
    await transport.dispose();
  });

  test(
    'the DEFAULT wiring reads ActiveChatThread — no injection, no fake',
    () async {
      // Every other test here injects `openChatThreadIds`, so all of them would
      addTearDown(ActiveChatThread.instance.resetForTest);
      final transport = FirebaseMessagingTransport(
        messaging: _MockMessaging(),
        localNotifications: _MockLocalNotifications(),
      );
      final screen = Object();

      transport.debugHandleForeground(
        _msg('m-a', const <String, String>{
          'type': 'chat',
          'conversationId': 'conv-1',
        }),
      );
      expect(
        transport.debugForegroundShownIds,
        <String>{'m-a'},
        reason: 'no chat open ⇒ shows',
      );

      ActiveChatThread.instance.enter(screen, () => <String>{'conv-1'});
      transport.debugHandleForeground(
        _msg('m-b', const <String, String>{
          'type': 'chat',
          'conversationId': 'conv-1',
        }),
      );
      expect(
        transport.debugForegroundShownIds,
        <String>{'m-a'},
        reason: 'thread now on screen ⇒ m-b suppressed',
      );

      ActiveChatThread.instance.leave(screen);
      transport.debugHandleForeground(
        _msg('m-c', const <String, String>{
          'type': 'chat',
          'conversationId': 'conv-1',
        }),
      );
      expect(
        transport.debugForegroundShownIds,
        <String>{'m-a', 'm-c'},
        reason: 'left the thread ⇒ shows again',
      );

      await transport.dispose();
    },
  );

  test(
    '`silent` is NOT hoisted out of the nested `data` blob — and an unhoisted '
    'silent therefore SHOWS (fail-loud, the recoverable direction)',
    () async {
      // Scope note: an earlier revision added `silent` to kNestedRoutingKeys.
      final data = <String, String>{
        'data': "{'requestId':'req-1','type':'new_request','silent':'True'}",
      };
      hoistNestedRoutingFields(data);
      expect(data['silent'], isNull);
      expect(data['requestId'], 'req-1', reason: 'routing keys still hoist');

      final transport = FirebaseMessagingTransport(
        messaging: _MockMessaging(),
        localNotifications: _MockLocalNotifications(),
        openChatThreadIds: () => const <String>{},
      );
      transport.debugHandleForeground(_msg('m-nested', data));
      expect(transport.debugForegroundShownIds, <String>{'m-nested'});
      await transport.dispose();
    },
  );
}
