import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/notification_dispatcher.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';

GoRouter _router() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => stub('home')),
      GoRoute(path: '/orders/:id', builder: (_, _) => stub('order')),
      GoRoute(path: '/orders/:id/rate', builder: (_, _) => stub('rate')),
      GoRoute(path: '/chat/:id', builder: (_, _) => stub('chat')),
      GoRoute(path: '/profile/kyc', builder: (_, _) => stub('kyc')),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => stub('settings-notifications'),
      ),
      GoRoute(
        path: '/jeeber/requests/:id',
        builder: (_, _) => stub('jeeber-request-detail'),
      ),
      GoRoute(
        path: '/jeeber/deliveries/:id/active',
        builder: (_, _) => stub('jeeber-active-delivery'),
      ),
      GoRoute(
        path: '/jeeber/pending-offers',
        builder: (_, _) => stub('jeeber-pending-offers'),
      ),
      // P2: the customer auction-phase surfaces.
      GoRoute(
        path: '/requests/:id/offers',
        builder: (_, _) => stub('offer-review'),
      ),
      GoRoute(
        path: '/requests/:id/waiting',
        builder: (_, _) => stub('waiting'),
      ),
    ],
  );
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) {
  return tester.pumpWidget(MaterialApp.router(routerConfig: router));
}

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late PushNotificationHandler handler;
  late GoRouter router;
  late NotificationDispatcher dispatcher;

  setUp(() {
    transport = FakePushTransport();
    badge = BadgeCountCubit();
    handler = PushNotificationHandler(transport: transport, badgeCount: badge);
    router = _router();
  });

  tearDown(() async {
    await dispatcher.dispose();
    await handler.close();
    await badge.close();
    router.dispose();
  });

  testWidgets('routes opened-app taps via deep-link map', (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await tester.runAsync(() async {
      transport.emitOpenedApp(
        NotificationMessage(
          id: 'a',
          category: NotificationCategory.delivery,
          title: 't',
          body: 'b',
          receivedAt: DateTime.utc(2026, 5, 17),
          data: const {'delivery_id': 'd-42'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/orders/d-42',
    );
  });

  testWidgets('routes banner taps after foreground emit', (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    transport.emitForeground(
      NotificationMessage(
        id: 'b',
        category: NotificationCategory.chat,
        title: 't',
        body: 'b',
        receivedAt: DateTime.utc(2026, 5, 17),
        data: const {'chat_id': 'c-1'},
      ),
    );
    await tester.pumpAndSettle();
    handler.tapBanner();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/chat/c-1',
    );
  });

  testWidgets('routes an opened new_request tap to the jeeber request screen', (
    tester,
  ) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await tester.runAsync(() async {
      transport.emitOpenedApp(
        NotificationMessage(
          id: 'nr',
          category: NotificationCategory.newRequest,
          title: 't',
          body: 'b',
          receivedAt: DateTime.utc(2026, 5, 17),
          data: const {'requestId': 'req-1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/jeeber/requests/req-1',
    );
  });

  testWidgets(
    'routes an opened offer_accepted tap to the jeeber ACTIVE-DELIVERY '
    'screen (run-23 CHECK B: not the empty pending-offers list)',
    (tester) async {
      await _pumpRouter(tester, router);
      dispatcher = NotificationDispatcher(handler: handler, router: router);

      await tester.runAsync(() async {
        transport.emitOpenedApp(
          NotificationMessage(
            id: 'oa',
            category: NotificationCategory.offerAccepted,
            title: 't',
            body: 'b',
            receivedAt: DateTime.utc(2026, 5, 17),
            data: const {
              'requestId': 'req-1',
              'request_id': 'req-1',
              'offerId': 'off-1',
              'deepLink': 'jeeb://offers/off-1',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/jeeber/deliveries/req-1/active',
      );
    },
  );

  testWidgets('an id-less offer_accepted tap still lands on pending-offers '
      '(last-resort surface — never a silent no-op)', (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await tester.runAsync(() async {
      transport.emitOpenedApp(
        NotificationMessage(
          id: 'oa-noid',
          category: NotificationCategory.offerAccepted,
          title: 't',
          body: 'b',
          receivedAt: DateTime.utc(2026, 5, 17),
          data: const {'offerId': 'off-1'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/jeeber/pending-offers',
    );
  });

  testWidgets('routes an opened offer_lost tap to the shell feed', (
    tester,
  ) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await tester.runAsync(() async {
      transport.emitOpenedApp(
        NotificationMessage(
          id: 'ol',
          category: NotificationCategory.offerLost,
          title: 't',
          body: 'b',
          receivedAt: DateTime.utc(2026, 5, 17),
          data: const {'requestId': 'req-1', 'offerId': 'off-2'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
  });

  testWidgets('messages with no destination do not navigate', (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await tester.runAsync(() async {
      transport.emitOpenedApp(
        NotificationMessage(
          id: 'c',
          category: NotificationCategory.other,
          title: 't',
          body: 'b',
          receivedAt: DateTime.utc(2026, 5, 17),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
  });

  testWidgets('cold-start initial message routes once', (tester) async {
    await _pumpRouter(tester, router);
    final cold = NotificationMessage(
      id: 'cold',
      category: NotificationCategory.rating,
      title: 't',
      body: 'b',
      receivedAt: DateTime.utc(2026, 5, 17),
      data: const {'delivery_id': 'd-9'},
    );
    dispatcher = NotificationDispatcher(
      handler: handler,
      router: router,
      initialMessage: Future.value(cold),
    );
    await dispatcher.whenColdRouted;
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/orders/d-9/rate',
    );
  });

  // ---- P2 (b01-20260725) ---------------------------------------------------

  // Helper: emit an opened-app (system-tray) tap and let the stream settle.
  Future<void> emitOpened(
    WidgetTester tester,
    NotificationMessage message,
  ) async {
    await tester.runAsync(() async {
      transport.emitOpenedApp(message);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  NotificationMessage p2Msg(
    String id,
    NotificationCategory category, {
    Map<String, String> data = const {'requestId': 'R', 'offerId': 'O'},
  }) {
    return NotificationMessage(
      id: id,
      category: category,
      title: 't',
      body: 'b',
      receivedAt: DateTime.utc(2026, 7, 25),
      data: data,
    );
  }

  // C1 — the reported bug: a backgrounded new-offer tap must open the
  // offer-review list, never the phantom `/orders/:requestId` hub.
  testWidgets('routes an opened newOffer tap to the offer-review list',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await emitOpened(tester, p2Msg('no1', NotificationCategory.newOffer));

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/requests/R/offers',
    );
    expect(find.text('offer-review'), findsOneWidget);
  });

  // C2 — the killed-app tap path.
  testWidgets('cold-start newOffer tap lands on the offer-review list',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(
      handler: handler,
      router: router,
      initialMessage:
          Future.value(p2Msg('no2', NotificationCategory.newOffer)),
    );
    await dispatcher.whenColdRouted;
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/requests/R/offers',
    );
  });

  // C3 — the in-app (foreground heads-up) banner tap routes through `opens`.
  testWidgets('in-app banner tap on a newOffer lands on the offer-review list',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    transport.emitForeground(p2Msg('no3', NotificationCategory.newOffer));
    await tester.pumpAndSettle();
    handler.tapBanner();
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/requests/R/offers',
    );
  });

  // C4 — F3: the expiry nudge lands on the waiting surface, the same target
  // the inbox row already uses.
  testWidgets('routes an opened requestExpired tap to the waiting screen',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await emitOpened(
      tester,
      p2Msg(
        're1',
        NotificationCategory.requestExpired,
        data: const {'requestId': 'R'},
      ),
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/requests/R/waiting',
    );
  });

  // C5 — F5: a CLIENT must never be routed to `/jeeber/requests/:id`
  // (its recovery path calls the jeeber-only feed → 403, FIX-REQUESTS.md:35).
  testWidgets('a CLIENT role refuses a new_request tap to the shell',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(
      handler: handler,
      router: router,
      roleResolver: () => UserRole.client,
    );

    await emitOpened(
      tester,
      p2Msg(
        'nr-c',
        NotificationCategory.newRequest,
        data: const {'requestId': 'R'},
      ),
    );

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
  });

  // C6 — fence: the guard must NOT over-refuse a legitimate jeeber tap (R7).
  testWidgets('a JEEBER role still reaches the jeeber request screen',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(
      handler: handler,
      router: router,
      roleResolver: () => UserRole.jeeber,
    );

    await emitOpened(
      tester,
      p2Msg(
        'nr-j',
        NotificationCategory.newRequest,
        data: const {'requestId': 'R'},
      ),
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/jeeber/requests/R',
    );
  });

  // C7 — back-compat: the pre-P2 constructor call (no roleResolver) is
  // unchanged and role-blind.
  testWidgets('no roleResolver keeps the legacy role-blind routing',
      (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await emitOpened(
      tester,
      p2Msg(
        'nr-n',
        NotificationCategory.newRequest,
        data: const {'requestId': 'R'},
      ),
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/jeeber/requests/R',
    );
  });

  // C8 — the EXACT `[jeeb-diag]` line the on-device E2E greps for.
  testWidgets('push_tapped diag line carries category/deepLink/resolved/role',
      (tester) async {
    final lines = <String>[];
    final priorSink = Diag.sink;
    final priorEnabled = Diag.enabledOverride;
    Diag.sink = lines.add;
    Diag.enabledOverride = true;
    addTearDown(() {
      Diag.sink = priorSink;
      Diag.enabledOverride = priorEnabled;
    });

    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(
      handler: handler,
      router: router,
      roleResolver: () => UserRole.client,
    );

    await emitOpened(tester, p2Msg('diag', NotificationCategory.newOffer));

    final tapped = lines.firstWhere(
      (l) => l.contains('"name":"push_tapped"'),
      orElse: () => '',
    );
    expect(tapped, isNotEmpty, reason: 'no push_tapped diag line emitted');
    expect(tapped, contains('"t":"evt"'));
    expect(tapped, contains('"category":"newOffer"'));
    expect(tapped, contains('"deepLink":"/requests/R/offers"'));
    expect(tapped, contains('"resolved":true'));
    expect(tapped, contains('"role":"client"'));
  });
}
