import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/notifications/presentation/push_banner_host.dart';

NotificationMessage _msg(String id, {String title = 'Title', String body = 'Body'}) {
  return NotificationMessage(
    id: id,
    category: NotificationCategory.delivery,
    title: title,
    body: body,
    receivedAt: DateTime.utc(2026, 5, 17),
    data: const {'delivery_id': 'd-1'},
  );
}

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

  Future<void> pumpHost(WidgetTester tester,
      {Duration autoDismiss = const Duration(seconds: 5)}) async {
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        autoDismiss: autoDismiss,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));
  }

  testWidgets('renders the banner when a foreground message arrives',
      (tester) async {
    await pumpHost(tester);
    await tester.runAsync(() async {
      transport.emitForeground(
          _msg('a', title: 'New delivery', body: 'Order #42'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('New delivery'), findsOneWidget);
    expect(find.text('Order #42'), findsOneWidget);
  });

  testWidgets('tap fires onBannerTap with the underlying message',
      (tester) async {
    NotificationMessage? tapped;
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        onBannerTap: (m) => tapped = m,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));

    await tester.runAsync(() async {
      transport.emitForeground(
        _msg('a', title: 'Banner Headline', body: 'Banner Body'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Banner Headline'), findsOneWidget);

    await tester.tap(find.text('Banner Headline'));
    await tester.pump();

    expect(tapped?.id, 'a');
    expect(handler.state.banner, isNull,
        reason: 'tapBanner should clear the banner');
  });

  testWidgets('dismiss button clears the banner without routing',
      (tester) async {
    NotificationMessage? tapped;
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        onBannerTap: (m) => tapped = m,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await tester.runAsync(() async {
      transport.emitForeground(_msg('a', title: 'Banner Headline'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Banner Headline'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();

    expect(tapped, isNull);
    expect(find.text('Banner Headline'), findsNothing);
  });

  testWidgets('banner auto-dismisses after the configured duration',
      (tester) async {
    await pumpHost(tester, autoDismiss: const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      transport.emitForeground(_msg('a', title: 'Auto Dismiss Banner'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('Auto Dismiss Banner'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Auto Dismiss Banner'), findsNothing);
  });
}
