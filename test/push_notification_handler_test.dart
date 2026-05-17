import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

NotificationMessage _message(String id, {NotificationCategory? category}) {
  return NotificationMessage(
    id: id,
    category: category ?? NotificationCategory.delivery,
    title: 'Title $id',
    body: 'Body $id',
    receivedAt: DateTime.utc(2026, 5, 17),
    data: const {'delivery_id': 'd-1'},
  );
}

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late PushNotificationHandler handler;

  setUp(() {
    transport = FakePushTransport(token: 'tok-1');
    badge = BadgeCountCubit();
    handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      historyLimit: 3,
    );
  });

  tearDown(() async {
    await handler.close();
    await badge.close();
  });

  test('foreground message becomes the banner and is recorded in history',
      () async {
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.banner?.id, 'a');
    expect(handler.state.history.map((m) => m.id), ['a']);
    expect(badge.state, 1);
  });

  test('duplicate ids are deduplicated', () async {
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.history, hasLength(1));
    expect(badge.state, 1);
  });

  test('history is capped at historyLimit (newest first)', () async {
    for (final id in ['a', 'b', 'c', 'd']) {
      transport.emitForeground(_message(id));
      await Future<void>.delayed(Duration.zero);
    }

    expect(handler.state.history.map((m) => m.id).toList(), ['d', 'c', 'b']);
  });

  test('dismissBanner clears the banner but keeps history', () async {
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);

    handler.dismissBanner();

    expect(handler.state.banner, isNull);
    expect(handler.state.history, hasLength(1));
  });

  test('tapBanner clears the banner and re-emits on opens stream', () async {
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);

    final opened = <NotificationMessage>[];
    final sub = handler.opens.listen(opened.add);
    handler.tapBanner();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(handler.state.banner, isNull);
    expect(opened.map((m) => m.id), ['a']);
  });

  test('transport opened-app taps surface on opens stream', () async {
    final opened = <NotificationMessage>[];
    final sub = handler.opens.listen(opened.add);
    transport.emitOpenedApp(_message('cold'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(opened.map((m) => m.id), ['cold']);
  });

  test('token refresh updates state.token', () async {
    transport.emitTokenRefresh('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(handler.state.token, 'tok-2');
  });

  test('bootstrap pulls initial permission and token', () async {
    await handler.bootstrap();
    expect(handler.state.permission, PushPermissionStatus.granted);
    expect(handler.state.token, 'tok-1');
  });

  test('clearBadge zeroes the badge cubit', () async {
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);
    expect(badge.state, 1);

    handler.clearBadge();
    expect(badge.state, 0);
  });
}
