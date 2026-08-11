// b02 wave D — the refresh bus routes by TOPIC.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

NotificationMessage _message(
  String id, {
  required NotificationCategory category,
  Map<String, String> data = const {'delivery_id': 'd-1'},
}) => NotificationMessage(
  id: id,
  category: category,
  title: 'Title $id',
  body: 'Body $id',
  receivedAt: DateTime.utc(2026, 7, 28),
  data: data,
);

/// Counts wake-ups on one topic slice of the bus.
class _TopicProbe {
  _TopicProbe(PushRefreshSignals bus, Set<RefreshTopic> topics) {
    _sub = bus.streamFor(topics).listen((_) => wakes++);
  }

  int wakes = 0;
  late final StreamSubscription<void> _sub;

  Future<void> cancel() => _sub.cancel();
}

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late PushRefreshSignals bus;
  late PushNotificationHandler handler;
  late _TopicProbe order;
  late _TopicProbe chat;
  late _TopicProbe feed;
  late _TopicProbe offers;
  late _TopicProbe unfiltered;

  setUp(() {
    transport = FakePushTransport(token: 'tok-1');
    badge = BadgeCountCubit();
    bus = PushRefreshSignals();
    handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      refreshSignals: bus,
    );
    order = _TopicProbe(bus, const {RefreshTopic.order});
    chat = _TopicProbe(bus, const {RefreshTopic.chat});
    feed = _TopicProbe(bus, const {RefreshTopic.feed});
    offers = _TopicProbe(bus, const {RefreshTopic.offers});
    unfiltered = _TopicProbe(bus, const <RefreshTopic>{});
  });

  tearDown(() async {
    await order.cancel();
    await chat.cancel();
    await feed.cancel();
    await offers.cancel();
    await unfiltered.cancel();
    await handler.close();
    await badge.close();
    await bus.dispose();
  });

  Future<void> arrive(NotificationMessage message) async {
    transport.emitForeground(message);
    await Future<void>.delayed(Duration.zero);
  }

  test('a chat push wakes the chat slice ONLY — the wave-D fan-out fix',
      () async {
    await arrive(_message(
      'm-chat',
      category: NotificationCategory.chat,
      data: const {'conversationId': 'conv-1'},
    ));

    expect(chat.wakes, 1, reason: 'the open thread must still re-pull');
    expect(order.wakes, isZero,
        reason: 'a message changes no delivery status: this is the read that '
            'used to fire on ChatDetailScreen (x3), DeliveryDetailScreen, '
            'ClientHome and ActiveDeliveries');
    expect(feed.wakes, isZero);
    expect(offers.wakes, isZero);
  });

  test('a busy conversation costs exactly one wake per message, on one slice',
      () async {
    for (var i = 0; i < 6; i++) {
      await arrive(_message(
        'm-chat-$i',
        category: NotificationCategory.chat,
        data: const {'conversationId': 'conv-1'},
      ));
    }

    expect(chat.wakes, 6);
    expect(order.wakes + feed.wakes + offers.wakes, isZero,
        reason: 'six messages used to be six wake-ups on every other surface');
  });

  test('a new_request push wakes the feed slice ONLY', () async {
    await arrive(_message(
      'm-new-request',
      category: NotificationCategory.newRequest,
      data: const {'requestId': 'r-1'},
    ));

    expect(feed.wakes, 1);
    expect(chat.wakes, isZero);
    expect(order.wakes, isZero);
    expect(offers.wakes, isZero);
  });

  test('a delivery push wakes the order slice ONLY', () async {
    await arrive(
      _message('m-delivery', category: NotificationCategory.delivery),
    );

    expect(order.wakes, 1);
    expect(chat.wakes, isZero);
    expect(feed.wakes, isZero);
    expect(offers.wakes, isZero);
  });

  test('offer_accepted wakes order AND offers, ONCE each — never twice on a '
      'subscriber that reads both', () async {
    final both = _TopicProbe(bus, const {
      RefreshTopic.order,
      RefreshTopic.offers,
    });
    addTearDown(both.cancel);

    await arrive(_message(
      'm-accepted',
      category: NotificationCategory.offerAccepted,
      data: const {'offerId': 'o-1'},
    ));

    expect(order.wakes, 1);
    expect(offers.wakes, 1);
    expect(
      both.wakes,
      1,
      reason: 'the bus publishes ONE event carrying a topic SET. Publishing '
          'one event per topic would wake a two-topic subscriber twice and '
          're-create, inside the fix, the duplicate fan-out it exists to '
          'remove',
    );
    expect(chat.wakes, isZero);
  });

  test('a new-offer push wakes order and offers, not chat or feed', () async {
    await arrive(_message(
      'm-offer',
      category: NotificationCategory.newOffer,
      data: const {'requestId': 'r-1'},
    ));

    expect(offers.wakes, 1);
    expect(order.wakes, 1, reason: 'the customer home summary paints Replies');
    expect(chat.wakes, isZero);
    expect(feed.wakes, isZero);
  });

  // Scope note, so this file does not read as claiming more than it proves:
  test('a category outside the publishing sets still publishes NOTHING — '
      'wave D changed the routing, not which categories reach the bus',
      () async {
    await arrive(_message('m-rating', category: NotificationCategory.rating));

    expect(unfiltered.wakes, isZero);
    expect(order.wakes, isZero);
    expect(chat.wakes, isZero);
    expect(feed.wakes, isZero);
    expect(offers.wakes, isZero);
  });

  test('a subscriber that declares NO topics keeps the pre-wave-D behaviour',
      () async {
    await arrive(
      _message('m-delivery', category: NotificationCategory.delivery),
    );
    await arrive(_message(
      'm-chat',
      category: NotificationCategory.chat,
      data: const {'conversationId': 'conv-1'},
    ));

    expect(unfiltered.wakes, 2,
        reason: 'an undeclared call site must not silently stop refreshing');
  });

  // INVERTED (close-out 2026-08-11). The id guard used to drop a delivery push
  // that carried no id — but the bus is payload-less and the id was discarded
  // after the guard read it, so the only effect was a live surface (the pinned
  // chat summary) staying on a stale status. The guard still applies to the
  // remaining orderish categories.
  test('a delivery push with no id still wakes the order topic — and ONLY it',
      () async {
    await arrive(_message(
      'm-delivery-no-id',
      category: NotificationCategory.delivery,
      data: const <String, String>{},
    ));

    expect(order.wakes, 1);
    expect(chat.wakes, isZero);
    expect(feed.wakes, isZero);
    expect(offers.wakes, isZero);
  });

  test('the id guard still applies to the other orderish pushes — a newOffer '
      'push with no id publishes nothing at all', () async {
    await arrive(_message(
      'm-newoffer-no-id',
      category: NotificationCategory.newOffer,
      data: const <String, String>{},
    ));

    expect(order.wakes, isZero);
    expect(offers.wakes, isZero);
    expect(unfiltered.wakes, isZero);
  });

  test('signalStatusChange still publishes on every topic (the cancel-request '
      'path)', () async {
    bus.signalStatusChange();
    await Future<void>.delayed(Duration.zero);

    expect(order.wakes, 1);
    expect(chat.wakes, 1);
    expect(feed.wakes, 1);
    expect(offers.wakes, 1);
  });

  test('an empty topic set publishes nothing', () async {
    bus.signal(const <RefreshTopic>{});
    await Future<void>.delayed(Duration.zero);

    expect(unfiltered.wakes, isZero);
  });
}
