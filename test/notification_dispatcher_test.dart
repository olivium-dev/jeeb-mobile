import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/notification_dispatcher.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

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
      transport.emitOpenedApp(NotificationMessage(
        id: 'a',
        category: NotificationCategory.delivery,
        title: 't',
        body: 'b',
        receivedAt: DateTime.utc(2026, 5, 17),
        data: const {'delivery_id': 'd-42'},
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/orders/d-42');
  });

  testWidgets('routes banner taps after foreground emit', (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    transport.emitForeground(NotificationMessage(
      id: 'b',
      category: NotificationCategory.chat,
      title: 't',
      body: 'b',
      receivedAt: DateTime.utc(2026, 5, 17),
      data: const {'chat_id': 'c-1'},
    ));
    await tester.pumpAndSettle();
    handler.tapBanner();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/chat/c-1');
  });

  testWidgets('messages with no destination do not navigate', (tester) async {
    await _pumpRouter(tester, router);
    dispatcher = NotificationDispatcher(handler: handler, router: router);

    await tester.runAsync(() async {
      transport.emitOpenedApp(NotificationMessage(
        id: 'c',
        category: NotificationCategory.other,
        title: 't',
        body: 'b',
        receivedAt: DateTime.utc(2026, 5, 17),
      ));
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

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/orders/d-9/rate');
  });
}
