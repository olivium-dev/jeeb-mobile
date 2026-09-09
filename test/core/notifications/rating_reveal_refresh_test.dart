import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/session/reviews_refresh_signals.dart';

class _ActorStore extends AuthTokenStore {
  String? actor = 'actor-a';
  @override
  Future<String?> get userId async => actor;
}

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late ReviewsRefreshSignals signals;
  late _ActorStore store;
  late PushNotificationHandler handler;
  late StreamSubscription<ReviewsRefreshEvent> subscription;
  late List<ReviewsRefreshEvent> events;

  setUp(() {
    transport = FakePushTransport();
    badge = BadgeCountCubit();
    signals = ReviewsRefreshSignals();
    store = _ActorStore();
    events = [];
    subscription = signals.stream.listen(events.add);
    handler = PushNotificationHandler(
      transport: transport,
      badgeCount: badge,
      tokenStore: store,
      reviewsRefreshSignals: signals,
      localRoles: () => {'client'},
    );
  });
  tearDown(() async {
    await handler.close();
    await subscription.cancel();
    await signals.dispose();
    await badge.close();
  });

  Future<void> arrive(Map<String, String> data, {String id = 'event'}) async {
    transport.emitForeground(
      NotificationMessage(
        id: id,
        category: NotificationCategory.fromData(data),
        title: '',
        body: '',
        receivedAt: DateTime.utc(2026),
        data: data,
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  for (final payload in [
    {'type': 'jeeb.rating_auto_revealed', 'user_id': 'actor-a'},
    {
      'notification_type': 'jeeb.rating_auto_revealed',
      'payload': '{"user_id":"actor-a","rating_value":5}',
    },
    {'type': 'jeeb.rating_auto_revealed', 'data': '{"user_id":"actor-a"}'},
  ]) {
    test(
      'explicit owner reveal invalidates only its signed-in recipient: $payload',
      () async {
        await arrive(payload);
        expect(events.map((e) => e.rateeId), ['actor-a']);
        expect(events.single.source, same(handler));
        await arrive(payload); // existing foreground dedup must still apply
        expect(events, hasLength(1));
      },
    );
  }

  for (final payload in [
    {'type': 'rating', 'user_id': 'actor-a'},
    {'category': 'rating', 'user_id': 'actor-a', 'rating_value': '5'},
    {'type': 'jeeb.rating_auto_revealed', 'user_id': 'other-actor'},
    {'type': 'jeeb.rating_auto_revealed', 'delivery_id': 'delivery-only'},
    {
      'type': 'jeeb.rating_auto_revealed',
      'user_id': 'actor-a',
      'payload': '{"user_id":"other-actor"}',
    },
    {'type': 'jeeb.rating_auto_revealed', 'payload': 'malformed'},
    {
      'type': 'jeeb.rating_auto_revealed',
      'user_id': 'actor-a',
      'audience_role': 'jeeber',
    },
  ]) {
    test(
      'prompt, unbound, conflicting or wrong audience event cannot invalidate: $payload',
      () async {
        await arrive(payload);
        expect(events, isEmpty);
      },
    );
  }

  test(
    'signed-out session never invalidates an old recipient profile',
    () async {
      store.actor = null;
      await arrive({'type': 'jeeb.rating_auto_revealed', 'user_id': 'actor-a'});
      expect(events, isEmpty);
    },
  );
}
