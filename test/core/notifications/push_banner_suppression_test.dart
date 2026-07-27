// b02 fg-suppression — the IN-APP half.
//
// The OS shade is not the only way a foreground push interrupts: `PushBannerHost`
// (wired at `app/app.dart:606`) renders `PushNotificationState.banner` as an
// in-app overlay. Suppressing the shade entry while that still popped would
// satisfy the letter of "silent" and none of its intent, so the same predicate
// gates both. These tests pin that, AND pin that the refresh signal — the whole
// reason a silent push exists — still fires for a suppressed push.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

NotificationMessage _push({
  required String id,
  required NotificationCategory category,
  Map<String, String> data = const <String, String>{},
}) =>
    NotificationMessage(
      id: id,
      category: category,
      title: 'Title',
      body: 'Body',
      receivedAt: DateTime.utc(2026, 7, 26),
      data: data,
    );

class _Harness {
  _Harness({Set<String> openChatThreadIds = const <String>{}}) {
    handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      refreshSignals: refresh,
      openChatThreadIds: () => openChatThreadIds,
    );
    refresh.stream.listen((_) => refreshCount++);
  }

  final transport = FakePushTransport(token: 'tok');
  final badge = BadgeCountCubit();
  final refresh = PushRefreshSignals();
  late final PushNotificationHandler handler;
  int refreshCount = 0;

  Future<void> emit(NotificationMessage message) async {
    transport.emitForeground(message);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> close() async {
    await handler.close();
    await badge.close();
    await refresh.dispose();
  }
}

void main() {
  test('a SILENT push raises NO in-app banner', () async {
    final h = _Harness();
    addTearDown(h.close);
    await h.emit(_push(
      id: 'p1',
      category: NotificationCategory.newRequest,
      data: const <String, String>{'requestId': 'req-1', 'silent': 'True'},
    ));
    expect(h.handler.state.banner, isNull);
  });

  test(
    'a SILENT push STILL fires the refresh signal — the point of going silent',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.emit(_push(
        id: 'p2',
        category: NotificationCategory.newRequest,
        data: const <String, String>{'requestId': 'req-1', 'silent': 'true'},
      ));
      expect(h.refreshCount, 1);
      // ...and it is still recorded, so the surface it drove is explicable.
      expect(h.handler.state.history, hasLength(1));
    },
  );

  test('a chat push for the OPEN thread raises no banner', () async {
    final h = _Harness(openChatThreadIds: const <String>{'conv-1'});
    addTearDown(h.close);
    await h.emit(_push(
      id: 'p3',
      category: NotificationCategory.chat,
      data: const <String, String>{'conversationId': 'conv-1'},
    ));
    expect(h.handler.state.banner, isNull);
  });

  test('a chat push for a DIFFERENT thread DOES raise a banner', () async {
    final h = _Harness(openChatThreadIds: const <String>{'conv-1'});
    addTearDown(h.close);
    await h.emit(_push(
      id: 'p4',
      category: NotificationCategory.chat,
      data: const <String, String>{'conversationId': 'conv-2'},
    ));
    expect(h.handler.state.banner?.id, 'p4');
  });

  test(
    'NEGATIVE CONTROL: a normal visible push raises a banner while a chat is '
    'open',
    () async {
      final h = _Harness(openChatThreadIds: const <String>{'conv-1'});
      addTearDown(h.close);
      await h.emit(_push(
        id: 'p5',
        category: NotificationCategory.kyc,
        data: const <String, String>{},
      ));
      expect(h.handler.state.banner?.id, 'p5');
    },
  );

  test('a suppressed push does not CLEAR an already-showing banner', () async {
    final h = _Harness(openChatThreadIds: const <String>{'conv-1'});
    addTearDown(h.close);
    await h.emit(_push(id: 'p6', category: NotificationCategory.kyc));
    expect(h.handler.state.banner?.id, 'p6');
    await h.emit(_push(
      id: 'p7',
      category: NotificationCategory.chat,
      data: const <String, String>{'conversationId': 'conv-1'},
    ));
    expect(
      h.handler.state.banner?.id,
      'p6',
      reason: 'suppression must not double as a dismiss',
    );
  });
}
