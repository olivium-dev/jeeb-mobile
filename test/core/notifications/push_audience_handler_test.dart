import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

class _FakeInbox implements LocalPushInbox {
  final List<LocalPushRecord> records = [];

  @override
  Future<void> append(LocalPushRecord record) async => records.add(record);
  @override
  Future<List<LocalPushRecord>> readAll() async => List.of(records);
  @override
  Future<bool> markRead(String id) async => false;
  @override
  Future<void> markAllRead() async {}
  @override
  Future<void> markAllNewRequestsSeenInFeed() async {}
}

NotificationMessage _newRequestPush({required String audienceRole}) {
  return NotificationMessage(
    id: 'nr-1',
    category: NotificationCategory.newRequest,
    title: 'New request nearby',
    body: 'A customer needs a jeeber',
    receivedAt: DateTime.utc(2026, 7, 25),
    data: {'audience_role': audienceRole, 'requestId': 'req-1'},
  );
}

void main() {
  // M-U8
  test('a jeeber-audience new_request push is suppressed for a client-only '
      'session: no banner, no history, no badge, no inbox row', () async {
    final transport = FakePushTransport(token: 'tok-1');
    final badge = BadgeCountCubit();
    final inbox = _FakeInbox();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      localInbox: inbox,
      localRoles: () => {'client'},
    );
    addTearDown(() async {
      await handler.close();
      await badge.close();
    });

    transport.emitForeground(_newRequestPush(audienceRole: 'driver'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.banner, isNull);
    expect(handler.state.history, isEmpty);
    expect(badge.state.unread, 0);
    expect(badge.state.newRequests, 0);
    expect(inbox.records, isEmpty);
  });

  // M-U9
  test('a jeeber-audience new_request push is accepted for a jeeber session: '
      'banner set, history 1, badge incremented, inbox appended', () async {
    final transport = FakePushTransport(token: 'tok-2');
    final badge = BadgeCountCubit();
    final inbox = _FakeInbox();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      localInbox: inbox,
      localRoles: () => {'jeeber'},
    );
    addTearDown(() async {
      await handler.close();
      await badge.close();
    });

    transport.emitForeground(_newRequestPush(audienceRole: 'driver'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.banner?.id, 'nr-1');
    expect(handler.state.history, hasLength(1));
    expect(badge.state.unread, 1);
    expect(badge.state.newRequests, 1);
    expect(inbox.records, hasLength(1));
  });

  // M-U10
  test('localRoles not wired (null) is a no-op: the message is accepted as '
      'before P1 — no behaviour change for a build that never wires it',
      () async {
    final transport = FakePushTransport(token: 'tok-3');
    final badge = BadgeCountCubit();
    final inbox = _FakeInbox();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      localInbox: inbox,
    );
    addTearDown(() async {
      await handler.close();
      await badge.close();
    });

    transport.emitForeground(_newRequestPush(audienceRole: 'driver'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.banner?.id, 'nr-1');
    expect(handler.state.history, hasLength(1));
    expect(badge.state.newRequests, 1);
    expect(inbox.records, hasLength(1));
  });
}
