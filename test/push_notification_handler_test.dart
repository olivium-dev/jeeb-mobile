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

    // b02 polling→push (chat push drives the open thread). This assertion USED
    // to read `does NOT signal` — and that was the whole bug. `ChatCubit` took
    // no push input, so on the deployed build a chat push landed and drove
    // nothing while `GET /v1/conversations/{id}/messages` ticked on a fixed 60s
    // phase. Now `chat` sits on the id-less branch alongside `offer_accepted` /
    // `new_request`, and `ChatCubit._refreshFromPush` re-pulls the ONE
    // conversation it renders (see
    // `test/features/chat/chat_push_drives_thread_test.dart`).
    test('a foreground chat push signals a refetch (drives the open thread)',
        () async {
      expect(
        await countSignalsFor(
          _message('s2', category: NotificationCategory.chat),
        ),
        1,
      );
    });

    // …and it does so with NO id in the payload, deliberately: the bus is
    // payload-less and the chat notifier's keys are `conversationId` /
    // `requestId`, none of which the id guard below reads first.
    test('a chat push with no ids at all still signals', () async {
      final bare = NotificationMessage(
        id: 's2b',
        category: NotificationCategory.chat,
        title: 'T',
        body: 'B',
        receivedAt: DateTime.utc(2026, 7, 26),
      );
      expect(await countSignalsFor(bare), 1);
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

    // PUSH-UI-REACTION (2026-07-05): a foreground `offer_accepted` push means
    // this jeeber just won a delivery — the "Your active deliveries" card
    // (ActiveDeliveriesCubit) subscribes to this same bus and must re-pull. The
    // on-device gap was that nothing signalled a refetch off this push, so the
    // card only surfaced after a force-restart.
    test('an offer_accepted push signals a status change (active-deliveries '
        'refetch)', () async {
      final accepted = NotificationMessage(
        id: 's4',
        category: NotificationCategory.offerAccepted,
        title: 'Offer accepted',
        body: 'The customer accepted your offer',
        receivedAt: DateTime.utc(2026, 5, 17),
        data: const {'offerId': 'off-1', 'requestId': 'req-9'},
      );
      expect(await countSignalsFor(accepted), 1);
    });

    test('an offer_accepted push signals even with no id (the card re-pulls '
        'its own snapshot)', () async {
      final acceptedNoId = NotificationMessage(
        id: 's5',
        category: NotificationCategory.offerAccepted,
        title: 'Offer accepted',
        body: 'b',
        receivedAt: DateTime.utc(2026, 5, 17),
      );
      expect(await countSignalsFor(acceptedNoId), 1);
    });

    // ---- P2 (b01-20260725), plan change C4 -------------------------------
    // `offer` and the expiry events used to arrive here inside the `delivery`
    // bucket. Splitting them into their own categories MUST preserve the
    // refresh signal, or the customer's Home/Replies surface stops re-pulling
    // on a foreground new-offer push and falls back to the slow wall-clock
    // poll. `dart analyze` is BLIND to this regression (the guard is an
    // `if`, not an exhaustive switch) — these two tests are the only fence.

    // B1
    test('a foreground newOffer push carrying a requestId still signals a '
        'status change (C4: the category split must not kill the re-pull)',
        () async {
      final newOffer = NotificationMessage(
        id: 'p2-1',
        category: NotificationCategory.newOffer,
        title: 'New offer on your request',
        body: 'Tap to review',
        receivedAt: DateTime.utc(2026, 7, 25),
        data: const {'requestId': 'req-9', 'offerId': 'off-1'},
      );
      expect(await countSignalsFor(newOffer), 1);
    });

    // B2
    test('a foreground requestExpired push carrying a requestId signals a '
        'status change', () async {
      final expired = NotificationMessage(
        id: 'p2-2',
        category: NotificationCategory.requestExpired,
        title: 'Still looking',
        body: 'b',
        receivedAt: DateTime.utc(2026, 7, 25),
        data: const {'requestId': 'req-9'},
      );
      expect(await countSignalsFor(expired), 1);
    });

    // B3 — matches the existing id-less `delivery` rule (no id → no signal).
    test('a newOffer push with NO id does NOT signal', () async {
      final noId = NotificationMessage(
        id: 'p2-3',
        category: NotificationCategory.newOffer,
        title: 'T',
        body: 'B',
        receivedAt: DateTime.utc(2026, 7, 25),
      );
      expect(await countSignalsFor(noId), 0);
    });

    test('an unknown (other) push is a no-op: no signal, no crash', () async {
      final unknown = NotificationMessage(
        id: 's6',
        category: NotificationCategory.other,
        title: 'T',
        body: 'B',
        receivedAt: DateTime.utc(2026, 5, 17),
        data: const {'weird': 'payload'},
      );
      expect(await countSignalsFor(unknown), 0);
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

    // B6 (P2): the offer-LIFECYCLE bus is jeeber-side only (offer_accepted /
    // offer_lost — a decision on a jeeber's OWN submitted offer). A customer's
    // inbound new bid carries an `offerId` too, but it must never flip a
    // jeeber's pending-offers row.
    test('a newOffer push with an offerId does NOT signal the (jeeber-side) '
        'offer-lifecycle bus', () async {
      final events = await eventsFor(
        offerMsg('o5', category: NotificationCategory.newOffer),
      );
      expect(events, isEmpty);
    });
  });

  // B7 (P2): a new-offer push is customer-side inbox noise — it bumps the
  // inbox total but must NOT touch the jeeber Dashboard-tab new-request badge.
  test('a newOffer push increments the inbox total but not the new-request '
      'badge', () async {
    transport.emitForeground(NotificationMessage(
      id: 'badge-1',
      category: NotificationCategory.newOffer,
      title: 'New offer on your request',
      body: 'Tap to review',
      receivedAt: DateTime.utc(2026, 7, 25),
      data: const {'requestId': 'req-9', 'offerId': 'off-1'},
    ));
    await Future<void>.delayed(Duration.zero);

    expect(badge.state.unread, 1);
    expect(badge.state.newRequests, 0);
  });
}
