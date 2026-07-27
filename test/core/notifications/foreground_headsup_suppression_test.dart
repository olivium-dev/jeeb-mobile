// b02 fg-suppression — the TRANSPORT-level early return.
//
// `FirebaseMessagingTransport._handleForeground` used to call
// `_localNotifications.show(...)` on EVERY `onMessage`, with no silent check
// and no open-thread check. It was never covered because `initialize()` touches
// three platform channels, so the only way to reach the handler on the VM is
// the `debugHandleForeground` seam.
//
// What this file can and cannot prove, stated plainly:
//   * PROVEN here — a suppressed push takes the early return BEFORE the render
//     path (observable via `debugForegroundShownIds`, which is written on the
//     line after the guard), and a normal push does NOT.
//   * NOT provable here — the `_localNotifications.show(...)` call itself is
//     inside `if (Platform.isAndroid)`, which is false on the macOS test VM.
//     That half is device evidence (a33 / s24); emulators cannot receive FCM.

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

FirebaseMessagingTransport _transport(Set<String> openThreads) =>
    FirebaseMessagingTransport(
      messaging: _MockMessaging(),
      localNotifications: _MockLocalNotifications(),
      openChatThreadIds: () => openThreads,
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

  test(
    'the DEFAULT wiring reads ActiveChatThread — no injection, no fake',
    () async {
      // Every other test here injects `openChatThreadIds`, so all of them would
      // pass even if the production default were wired to nothing. This one
      // constructs the transport the way `app.dart:509` does and drives the
      // real registry.
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
      // No captured payload nests it (the push service emits it flat), so the
      // key was dropped. This test pins the resulting behaviour so the choice
      // is explicit rather than accidental: a nested-only `silent` reads as
      // "not silent" and the push renders.
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
