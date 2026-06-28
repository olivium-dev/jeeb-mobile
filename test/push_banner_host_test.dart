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

  testWidgets('exposes capturable push_banner keys for sender + message',
      (tester) async {
    await pumpHost(tester);
    await tester.runAsync(() async {
      // Chat push: gateway sends title=sender, body=message.
      transport.emitForeground(
        NotificationMessage(
          id: 'c1',
          category: NotificationCategory.chat,
          title: 'Karim',
          body: 'On my way 🚗',
          receivedAt: DateTime.utc(2026, 5, 17),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.byKey(const Key('push_banner_title')), findsOneWidget);
    expect(find.byKey(const Key('push_banner_body')), findsOneWidget);
    final title = tester.widget<Text>(find.byKey(const Key('push_banner_title')));
    final body = tester.widget<Text>(find.byKey(const Key('push_banner_body')));
    expect(title.data, 'Karim');
    expect(body.data, 'On my way 🚗');
  });

  testWidgets('permission prompt overlays only when opted-in AND denied',
      (tester) async {
    final deniedTransport =
        FakePushTransport(permission: PushPermissionStatus.denied);
    final deniedBadge = BadgeCountCubit();
    final deniedHandler = PushNotificationHandler(
      transport: deniedTransport,
      badgeCount: deniedBadge,
    );
    addTearDown(() async {
      await deniedHandler.close();
      await deniedBadge.close();
    });

    var enableTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: deniedHandler,
        showPermissionPrompt: true,
        onEnablePermission: () => enableTaps++,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));

    // Not shown until the handler resolves a non-granted status.
    expect(find.byKey(const Key('notif_perm_enable')), findsNothing);

    await deniedHandler.bootstrap();
    await tester.pump();

    expect(find.byKey(const Key('notif_perm_enable')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notif_perm_enable')));
    await tester.pump();
    expect(enableTaps, 1);

    // "Not now" hides it for the session.
    await tester.tap(find.byKey(const Key('notif_perm_dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('notif_perm_enable')), findsNothing);
  });

  testWidgets('permission prompt stays hidden when permission is granted',
      (tester) async {
    // Default transport is granted; opting in must not surface the prompt.
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        showPermissionPrompt: true,
        onEnablePermission: () {},
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await handler.bootstrap();
    await tester.pump();

    expect(find.byKey(const Key('notif_perm_enable')), findsNothing);
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

    // Dismiss is keyed (the tooltip was removed in the P1 fix — see below), so
    // QA + this test target it by key rather than by tooltip.
    await tester.tap(find.byKey(const Key('push_banner_dismiss')));
    await tester.pump();

    expect(tapped, isNull);
    expect(find.text('Banner Headline'), findsNothing);
  });

  // P1 regression (sprint-05 push-proof §1d). PushBannerHost is mounted ABOVE
  // the Navigator in app.dart, so there is NO `Overlay` ancestor. The dismiss
  // `IconButton` used to carry `tooltip: 'Dismiss'`; since Flutter 3.10
  // `Tooltip` builds an `OverlayPortal`, which calls `Overlay.of(context)` at
  // build time and throws "No Overlay widget found" when none exists. That
  // crash (caught by the framework) silently dropped the whole foreground
  // banner on device. This pumps the host in an Overlay-LESS tree (mirroring
  // app.dart) and asserts the banner builds + the dismiss control works with
  // NO exception. Revert the fix (re-add `tooltip:`) → this goes RED.
  testWidgets(
      'foreground banner builds + dismiss works with NO Overlay ancestor '
      '(P1: Tooltip "No Overlay widget found" regression)', (tester) async {
    // Deliberately NO MaterialApp / Navigator => NO Overlay in the tree, just
    // the inherited widgets _BannerCard actually needs (Directionality for
    // PositionedDirectional, MediaQuery for the safe-area padding, Theme for
    // the colorScheme/textTheme).
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Theme(
            data: ThemeData.light(),
            child: PushBannerHost(
              handler: handler,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      transport.emitForeground(
        _msg('overlayless', title: 'Karim', body: 'On my way 🚗'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    // _BannerCard builds here — with the old `tooltip:` this throws.
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'banner must build without an Overlay ancestor');
    expect(find.byKey(const Key('push_banner_title')), findsOneWidget);
    expect(find.byKey(const Key('push_banner_dismiss')), findsOneWidget);

    // The dismiss affordance actually clears the banner — no Overlay needed.
    await tester.tap(find.byKey(const Key('push_banner_dismiss')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('push_banner_title')), findsNothing);
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
