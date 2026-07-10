
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/notifications/presentation/push_banner_host.dart';

NotificationMessage _msg(String id) => NotificationMessage(
      id: id,
      category: NotificationCategory.delivery,
      title: 'New delivery',
      body: 'Order #42',
      receivedAt: DateTime.utc(2026, 6, 30),
    );

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late PushNotificationHandler handler;

  setUp(() {
    transport = FakePushTransport();
    badge = BadgeCountCubit();
    handler = PushNotificationHandler(transport: transport, badgeCount: badge);
  });

  tearDown(() async {
    await handler.close();
    await badge.close();
  });

  // Mounts PushBannerHost through the SAME seam used in lib/app/app.dart:
  // as the `builder:` of MaterialApp.router. That makes the host the PARENT
  // of the Navigator and therefore ABOVE the Navigator's Overlay. Anything
  // the banner builds that needs an Overlay ancestor (a Tooltip mounts an
  // OverlayPortal on show) has none here — the exact topology that produced
  // the P1 crash: "No Overlay widget found. Tooltip widgets require an
  // Overlay widget ancestor". autoDismiss is zeroed so the banner stays
  // pinned and leaks no timer.
  Future<void> pumpProductionHost(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: SizedBox.expand()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => PushBannerHost(
          handler: handler,
          autoDismiss: Duration.zero,
          child: child!,
        ),
      ),
    );
  }

  Future<void> emitForeground(WidgetTester tester, String id) async {
    await tester.runAsync(() async {
      transport.emitForeground(_msg(id));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  testWidgets(
    'foreground banner mounted above the Navigator does not require an '
    'Overlay ancestor (regression: BUG-P1a "No Overlay widget found")',
    (tester) async {
      await pumpProductionHost(tester);
      await emitForeground(tester, 'overlay-regression');

      // Banner + its dismiss control are on screen, above the Overlay.
      expect(find.text('New delivery'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Long-press forces a Tooltip (if present) to mount its OverlayPortal
      // and look up an Overlay that does not exist above PushBannerHost,
      // which is what threw the P1 error. Without the `tooltip:` parameter
      // there is nothing to show, so the interaction is inert.
      await tester.longPress(find.byIcon(Icons.close));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // takeException() reads the binding's pending-exception slot, which is
      // where both FlutterError.onError and zone (Timer) errors land — the
      // tooltip overlay error is thrown from a Timer, so this is the channel
      // that actually catches it.
      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'PushBannerHost is injected via MaterialApp.router.builder, '
            'so it sits ABOVE the Navigator Overlay. No banner descendant may '
            'depend on an Overlay ancestor. Got: $exception',
      );
    },
  );
}
