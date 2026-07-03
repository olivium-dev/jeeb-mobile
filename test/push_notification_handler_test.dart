import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/offer_lifecycle_signals.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
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
    expect(badge.state.unread, 1);
  });

  test('duplicate ids are deduplicated', () async {
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);
    transport.emitForeground(_message('a'));
    await Future<void>.delayed(Duration.zero);

    expect(handler.state.history, hasLength(1));
    expect(badge.state.unread, 1);
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
    expect(badge.state.unread, 1);

    handler.clearBadge();
    expect(badge.state.unread, 0);
  });

  group('push→refetch signal (Lane C)', () {
    Future<int> countSignalsFor(NotificationMessage message) async {
      final t = FakePushTransport(token: 'tok-x');
      final b = BadgeCountCubit();
      final signals = PushRefreshSignals();
      var count = 0;
      final sub = signals.stream.listen((_) => count += 1);
      final h = PushNotificationHandler(
        transport: t,
        badgeCount: b,
        refreshSignals: signals,
      );
      addTearDown(() async {
        await sub.cancel();
        await h.close();
        await b.close();
        await signals.dispose();
      });
      t.emitForeground(message);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return count;
    }

    test('a foreground delivery push carrying an id signals a status change',
        () async {
      expect(await countSignalsFor(_message('s1')), 1);
    });

    test('a non-delivery (chat) push does NOT signal a status change', () async {
      expect(
        await countSignalsFor(
          _message('s2', category: NotificationCategory.chat),
        ),
        0,
      );
    });

    test('a delivery push with no order/delivery/request id does NOT signal',
        () async {
      final noId = NotificationMessage(
        id: 's3',
        category: NotificationCategory.delivery,
        title: 'T',
        body: 'B',
        receivedAt: DateTime.utc(2026, 5, 17),
      );
      expect(await countSignalsFor(noId), 0);
    });
  });

  group('offer-lifecycle signal (sprint-009)', () {
    Future<List<OfferLifecycleEvent>> eventsFor(
      NotificationMessage message,
    ) async {
      final t = FakePushTransport(token: 'tok-o');
      final b = BadgeCountCubit();
      final bus = OfferLifecycleSignals();
      final events = <OfferLifecycleEvent>[];
      final sub = bus.stream.listen(events.add);
      final h = PushNotificationHandler(
        transport: t,
        badgeCount: b,
        offerLifecycleSignals: bus,
      );
      addTearDown(() async {
        await sub.cancel();
        await h.close();
        await b.close();
        await bus.dispose();
      });
      t.emitForeground(message);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return events;
    }

    NotificationMessage offerMsg(
      String id, {
      required NotificationCategory category,
      Map<String, String> data = const {'offerId': 'off-1'},
    }) {
      return NotificationMessage(
        id: id,
        category: category,
        title: 'Offer update',
        body: 'b',
        receivedAt: DateTime.utc(2026, 5, 17),
        data: data,
      );
    }

    test('offer_accepted push signals accepted=true with the offerId',
        () async {
      final events = await eventsFor(
        offerMsg('o1', category: NotificationCategory.offerAccepted),
      );
      expect(events, hasLength(1));
      expect(events.single.offerId, 'off-1');
      expect(events.single.accepted, isTrue);
    });

    test('offer_lost push signals accepted=false', () async {
      final events = await eventsFor(
        offerMsg('o2', category: NotificationCategory.offerLost),
      );
      expect(events, hasLength(1));
      expect(events.single.accepted, isFalse);
    });

    test('an offer push with no offerId does NOT signal (tap still routes to '
        'the list)', () async {
      final events = await eventsFor(
        offerMsg('o3',
            category: NotificationCategory.offerAccepted, data: const {}),
      );
      expect(events, isEmpty);
    });

    test('a non-offer (delivery) push does NOT signal the offer bus', () async {
      final events = await eventsFor(
        offerMsg('o4', category: NotificationCategory.delivery),
      );
      expect(events, isEmpty);
    });
  });
}
