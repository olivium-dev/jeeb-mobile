import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

/// F12 (M7): the audience gate already fails a mismatched push silently
/// (no banner/history/badge). This proves the drop also emits the greppable
/// `JEEB-PUSH-DROPPED` tripwire, independent of the JSON Diag event.
NotificationMessage _newRequestPush({required String audienceRole}) {
  return NotificationMessage(
    id: 'nr-tripwire-1',
    category: NotificationCategory.newRequest,
    title: 'New request nearby',
    body: 'A customer needs a jeeber',
    receivedAt: DateTime.utc(2026, 8, 22),
    data: {'audience_role': audienceRole, 'requestId': 'req-tripwire'},
  );
}

void main() {
  test('a suppressed push logs JEEB-PUSH-DROPPED with reason and type',
      () async {
    final originalDebugPrint = debugPrint;
    final lines = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    final transport = FakePushTransport(token: 'tok-tripwire');
    final badge = BadgeCountCubit();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      localRoles: () => {'client'},
    );
    addTearDown(() async {
      await handler.close();
      await badge.close();
    });

    transport.emitForeground(_newRequestPush(audienceRole: 'driver'));
    await Future<void>.delayed(Duration.zero);

    expect(
      lines,
      contains('JEEB-PUSH-DROPPED reason=audience_mismatch type=newRequest'),
    );
  });

  test('an accepted push does NOT log JEEB-PUSH-DROPPED', () async {
    final originalDebugPrint = debugPrint;
    final lines = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    final transport = FakePushTransport(token: 'tok-tripwire-2');
    final badge = BadgeCountCubit();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      localRoles: () => {'jeeber'},
    );
    addTearDown(() async {
      await handler.close();
      await badge.close();
    });

    transport.emitForeground(_newRequestPush(audienceRole: 'driver'));
    await Future<void>.delayed(Duration.zero);

    expect(lines.where((l) => l.startsWith('JEEB-PUSH-DROPPED')), isEmpty);
  });
}
