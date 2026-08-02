import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

/// S16 ACCEPTANCE LOCK — receive-side of the chat-send => push chain.
/// The live gate requires that a >=6-message two-way conversation produces a
NotificationMessage _chatPush(String id, String text, String conversationId) {
  // Mirrors FirebaseMessagingTransport._toDomain output for a gateway chat
  final data = <String, String>{
    'type': 'chat',
    'conversationId': conversationId,
    'title': 'New message',
    'body': text,
  };
  return NotificationMessage(
    id: id,
    category: NotificationCategory.fromData(data),
    title: 'New message',
    body: text,
    receivedAt: DateTime.utc(2026, 6, 27),
    data: data,
  );
}

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late PushNotificationHandler handler;

  setUp(() {
    transport = FakePushTransport(token: 'tok-recipient');
    badge = BadgeCountCubit();
    handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      // Acceptance needs >=6 retained; keep the default-class limit so the
      historyLimit: 20,
    );
  });

  tearDown(() async {
    await handler.close();
    await badge.close();
  });

  test('six distinct chat pushes each surface a banner, are all retained, '
      'and badge counts every one', () async {
    const conversationId = 'conv-acceptance-1';
    final banners = <String>[];
    final sub = handler.stream.listen((s) {
      final b = s.banner;
      if (b != null) banners.add(b.id);
    });

    for (var i = 1; i <= 6; i++) {
      transport.emitForeground(_chatPush('m-$i', 'message $i', conversationId));
      await Future<void>.delayed(Duration.zero);
    }
    await sub.cancel();

    // 1) Every one of the six distinct messages produced its own banner —
    expect(banners, ['m-1', 'm-2', 'm-3', 'm-4', 'm-5', 'm-6']);

    // 2) All six are retained in history (newest-first), proving none were
    expect(
      handler.state.history.map((m) => m.id).toList(),
      ['m-6', 'm-5', 'm-4', 'm-3', 'm-2', 'm-1'],
    );

    // 3) The badge counts every inbound message — the recipient sees "6".
    expect(badge.state.unread, 6);

    // 4) Each message is categorised as chat and deep-links back to the
    for (final msg in handler.state.history) {
      expect(msg.category, NotificationCategory.chat);
      expect(deepLinkForMessage(msg), '/chat/$conversationId');
    }
  });

  test('a genuinely duplicated delivery of the same message id is collapsed '
      '(no double-banner) while distinct ids are not', () async {
    const conversationId = 'conv-acceptance-2';
    transport.emitForeground(_chatPush('m-dup', 'hello', conversationId));
    await Future<void>.delayed(Duration.zero);
    // FCM can deliver the same messageId twice (retry/at-least-once). That must
    transport.emitForeground(_chatPush('m-dup', 'hello', conversationId));
    await Future<void>.delayed(Duration.zero);
    transport.emitForeground(_chatPush('m-next', 'world', conversationId));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.history.map((m) => m.id).toList(),
        ['m-next', 'm-dup']);
    expect(badge.state.unread, 2);
  });
}
