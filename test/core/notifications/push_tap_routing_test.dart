// G9 push-tap routing: the `deepLink` precedence rule + the LOCAL (app-posted)
// notification tap path, which never reached the dispatcher before.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/notification_dispatcher.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';

class _MockMessaging extends Mock implements FirebaseMessaging {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

NotificationMessage _msg(
  NotificationCategory category,
  Map<String, String> data, {
  String id = 'm-1',
}) => NotificationMessage(
  id: id,
  category: category,
  title: 't',
  body: 'b',
  receivedAt: DateTime.utc(2026, 9, 4),
  data: data,
);

GoRouter _router() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => stub('home')),
      GoRoute(path: '/chat/:id', builder: (_, _) => stub('chat')),
      GoRoute(
        path: '/requests/:id/offers',
        builder: (_, _) => stub('offer-review'),
      ),
      GoRoute(
        path: '/orders/:id/tracking',
        builder: (_, _) => stub('tracking'),
      ),
      GoRoute(
        path: '/jeeber/deliveries/:id/active',
        builder: (_, _) => stub('jeeber-active-delivery'),
      ),
    ],
  );
}

void main() {
  group('routeFromPushDeepLink', () {
    test('accepts an already-canonical in-app path', () {
      expect(routeFromPushDeepLink('/requests/R/offers'), '/requests/R/offers');
    });

    test('folds the jeeb:// custom scheme host back into the path', () {
      expect(routeFromPushDeepLink('jeeb://chat/c-1'), '/chat/c-1');
      expect(
        routeFromPushDeepLink('jeeb://requests/R/offers'),
        '/requests/R/offers',
      );
    });

    test('accepts the producer shapes the notification centre can emit', () {
      expect(
        routeFromPushDeepLink('jeeb://requests/req-1/offers'),
        '/requests/req-1/offers',
      );
      expect(
        routeFromPushDeepLink('jeeb://jeeber/deliveries/req-1/active'),
        '/jeeber/deliveries/req-1/active',
      );
    });

    test('preserves a query string', () {
      expect(
        routeFromPushDeepLink('jeeb://orders/d-1/tracking?deliveryId=x'),
        '/orders/d-1/tracking?deliveryId=x',
      );
    });

    test('REJECTS jeeb://offers/<offerId> — no route is keyed by offer id', () {
      expect(routeFromPushDeepLink('jeeb://offers/off-1'), isNull);
    });

    test('rejects foreign schemes, unknown routes, and junk', () {
      expect(routeFromPushDeepLink('https://evil.example/requests/R/offers'),
          isNull);
      expect(routeFromPushDeepLink('jeeb://admin/danger'), isNull);
      expect(routeFromPushDeepLink('/not-a-route'), isNull);
      expect(routeFromPushDeepLink('   '), isNull);
      expect(routeFromPushDeepLink(null), isNull);
    });
  });

  group('deepLinkForMessage deepLink precedence', () {
    test('an explicit deepLink beats the category rule', () {
      final path = deepLinkForMessage(
        _msg(NotificationCategory.delivery, const {
          'delivery_id': 'd-1',
          'deepLink': 'jeeb://orders/d-1/tracking',
        }),
      );
      expect(path, '/orders/d-1/tracking');
    });

    test('snake_case deep_link is honoured too', () {
      final path = deepLinkForMessage(
        _msg(NotificationCategory.chat, const {
          'chat_id': 'c-1',
          'deep_link': '/requests/R/offers',
        }),
      );
      expect(path, '/requests/R/offers');
    });

    test('an unmappable jeeb://offers/<id> falls back to the category rule', () {
      final path = deepLinkForMessage(
        _msg(NotificationCategory.offerAccepted, const {
          'requestId': 'req-1',
          'offerId': 'off-1',
          'deepLink': 'jeeb://offers/off-1',
        }),
      );
      expect(path, '/jeeber/deliveries/req-1/active');
    });

    test('a CLIENT still refuses a jeeber-only deepLink', () {
      final path = deepLinkForMessage(
        _msg(NotificationCategory.chat, const {
          'chat_id': 'c-1',
          'deepLink': 'jeeb://jeeber/deliveries/d-1/active',
        }),
        role: UserRole.client,
      );
      expect(path, '/chat/c-1');
    });
  });

  group('local (app-posted) notification taps', () {
    late FirebaseMessagingTransport transport;

    setUp(() {
      transport = FirebaseMessagingTransport(
        messaging: _MockMessaging(),
        localNotifications: _MockLocalNotifications(),
      );
    });

    tearDown(() => transport.dispose());

    test('a JSON payload tap reaches onMessageOpenedApp tagged src=local',
        () async {
      final origin = _msg(NotificationCategory.newOffer, const {
        'type': 'offer',
        'category': 'newOffer',
        'offerId': 'off-1',
        'deepLink': 'jeeb://requests/R/offers',
      }, id: 'fcm-77');
      final opened = transport.onMessageOpenedApp.first;

      transport.debugHandleLocalTap(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: FirebaseMessagingTransport.debugLocalPayload(origin),
        ),
      );

      final message = await opened;
      expect(message.id, 'fcm-77');
      expect(message.category, NotificationCategory.newOffer);
      expect(message.data['deepLink'], 'jeeb://requests/R/offers');
      expect(message.openSource, kPushOpenSourceLocal);
      expect(deepLinkForMessage(message), '/requests/R/offers');
    });

    test('a malformed or unknown payload never emits an open', () async {
      final seen = <NotificationMessage>[];
      final sub = transport.onMessageOpenedApp.listen(seen.add);
      for (final payload in <String?>[null, '', '{not json', 'legacy-id']) {
        transport.debugHandleLocalTap(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: payload,
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(seen, isEmpty);
    });
  });

  group('NotificationDispatcher', () {
    late FakePushTransport transport;
    late BadgeCountCubit badge;
    late PushNotificationHandler handler;
    late GoRouter router;
    late NotificationDispatcher dispatcher;

    setUp(() {
      transport = FakePushTransport();
      badge = BadgeCountCubit();
      handler = PushNotificationHandler(
        transport: transport,
        badgeCount: badge,
      );
      router = _router();
    });

    tearDown(() async {
      await dispatcher.dispose();
      await handler.close();
      await badge.close();
      router.dispose();
    });

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

    testWidgets('routes a LOCAL-source tap and logs src in push_tapped',
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

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      dispatcher = NotificationDispatcher(handler: handler, router: router);

      await emitOpened(
        tester,
        _msg(NotificationCategory.newOffer, const {
          'offerId': 'off-1',
          'deepLink': 'jeeb://requests/R/offers',
        }, id: 'local-1').withOpenSource(kPushOpenSourceLocal),
      );

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/requests/R/offers',
      );
      final tapped = lines.firstWhere(
        (l) => l.contains('"name":"push_tapped"'),
        orElse: () => '',
      );
      expect(tapped, contains('"src":"local"'));
      expect(tapped, contains('"deepLink":"/requests/R/offers"'));
    });

    // R13/F1: one foreground push posts BOTH an in-app banner and a tray entry.
    testWidgets('a tray tap still routes after an in-app banner tap of the '
        'SAME push', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      dispatcher = NotificationDispatcher(handler: handler, router: router);

      final message = _msg(NotificationCategory.chat, const {
        'chat_id': 'c-1',
      }, id: 'banner-then-tray');

      transport.emitForeground(message);
      await tester.pumpAndSettle();
      handler.tapBanner();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/chat/c-1',
      );

      router.go('/');
      await tester.pumpAndSettle();
      await emitOpened(tester, message.withOpenSource(kPushOpenSourceLocal));

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/chat/c-1',
      );
    });

    testWidgets('a swallowed duplicate emits a push_tap_deduped diag',
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

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      dispatcher = NotificationDispatcher(handler: handler, router: router);

      final message = _msg(NotificationCategory.chat, const {
        'chat_id': 'c-1',
      }, id: 'dedupe-diag');
      await emitOpened(tester, message.withOpenSource(kPushOpenSourceFcm));
      await emitOpened(tester, message.withOpenSource(kPushOpenSourceLaunch));

      final deduped = lines.firstWhere(
        (l) => l.contains('"name":"push_tap_deduped"'),
        orElse: () => '',
      );
      expect(deduped, contains('"src":"launch"'));
    });

    testWidgets('the same tap delivered twice routes once', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      dispatcher = NotificationDispatcher(handler: handler, router: router);

      final message = _msg(NotificationCategory.chat, const {
        'chat_id': 'c-1',
      }, id: 'dup-1');
      await emitOpened(tester, message.withOpenSource(kPushOpenSourceLaunch));
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/chat/c-1',
      );

      router.go('/');
      await tester.pumpAndSettle();
      await emitOpened(tester, message.withOpenSource(kPushOpenSourceFcm));
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });
  });
}
