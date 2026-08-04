// M6 class-3b — the two `core/notifications` presentation surfaces imported no
// kit and no Midnight token, so they were never given a Midnight pass. These
// assertions read the paint off the widgets; the goldens cannot see a 320px
// ink swap (wave-C standing finding).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/notifications/presentation/notification_permission_prompt.dart';
import 'package:jeeb_mobile/core/notifications/presentation/push_banner_host.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';

/// `colorScheme.primary` under Midnight. Named so a failure reads as the
/// budget violation it is rather than as an opaque hex mismatch.
const Color _orange = Color(0xFFD73B00);

JeebSemanticColors get _semantics => JeebSemanticColors.midnight();

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.midnight(),
      home: Scaffold(body: child),
    );

ColorScheme _scheme(WidgetTester tester, Type of) =>
    Theme.of(tester.element(find.byType(of))).colorScheme;

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

Color _iconInk(WidgetTester tester, IconData glyph) =>
    tester.widget<Icon>(find.byIcon(glyph)).color!;

void main() {
  group('PushBannerHost banner surface', () {
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

    Future<void> pumpBanner(WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          PushBannerHost(
            handler: handler,
            autoDismiss: Duration.zero,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.runAsync(() async {
        transport.emitForeground(
          NotificationMessage(
            id: 'a',
            category: NotificationCategory.delivery,
            title: 'New delivery',
            body: 'Order #42',
            receivedAt: DateTime.utc(2026, 5, 17),
            data: const <String, String>{'delivery_id': 'd-1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }

    testWidgets('is opaque raised navy with a glass hairline and a float lift',
        (WidgetTester tester) async {
      await pumpBanner(tester);
      final ColorScheme scheme = _scheme(tester, PushBannerHost);
      final BoxDecoration decoration =
          _decorationOf(tester, find.byKey(pushBannerCardKey));

      // Opaque, not glass: this card lands over arbitrary content (R3/R11's
      // live map included), where a white-7%/10% fill is unreadable.
      expect(decoration.color, scheme.surfaceContainerHigh);
      expect(decoration.color!.a, 1.0);
      expect(decoration.border!.top.color, _semantics.glassBorder);
      expect(decoration.border!.top.width, 1);
      expect(decoration.borderRadius,
          BorderRadius.circular(JeebRadii.lg));
      expect(decoration.boxShadow, JeebShadows.floatNav);
    });

    testWidgets('the category glyph spends no orange',
        (WidgetTester tester) async {
      await pumpBanner(tester);
      final ColorScheme scheme = _scheme(tester, PushBannerHost);

      expect(_iconInk(tester, Icons.local_shipping_outlined), scheme.secondary);
      expect(_iconInk(tester, Icons.local_shipping_outlined), isNot(_orange));
      expect(_iconInk(tester, Icons.local_shipping_outlined),
          isNot(scheme.primary));
    });

    testWidgets('title and body read the Midnight ramp, not textTheme',
        (WidgetTester tester) async {
      await pumpBanner(tester);
      final ColorScheme scheme = _scheme(tester, PushBannerHost);

      expect(tester.widget<Text>(find.text('New delivery')).style!.color,
          scheme.onSurface);
      expect(tester.widget<Text>(find.text('Order #42')).style!.color,
          _semantics.mutedText);
      // A recolour would have left the Material shell standing.
      expect(find.byType(Card), findsNothing);
    });
  });

  group('NotificationPermissionPrompt surface', () {
    Future<void> pumpPrompt(WidgetTester tester) => tester.pumpWidget(
          _host(
            NotificationPermissionPrompt(
              onEnable: () {},
              onDismiss: () {},
            ),
          ),
        );

    testWidgets('takes the same opaque raised-navy recipe as the banner',
        (WidgetTester tester) async {
      await pumpPrompt(tester);
      final ColorScheme scheme = _scheme(tester, NotificationPermissionPrompt);
      final BoxDecoration decoration = _decorationOf(
        tester,
        find
            .descendant(
              of: find.byType(NotificationPermissionPrompt),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      expect(decoration.color, scheme.surfaceContainerHigh);
      expect(decoration.border!.top.color, _semantics.glassBorder);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.lg));
      expect(decoration.boxShadow, JeebShadows.floatNav);
    });

    testWidgets('the header glyph is periwinkle, never the brand orange',
        (WidgetTester tester) async {
      await pumpPrompt(tester);
      final ColorScheme scheme = _scheme(tester, NotificationPermissionPrompt);

      final Color ink = _iconInk(tester, Icons.notifications_active_outlined);
      expect(ink, scheme.secondary);
      expect(ink, isNot(_orange));
    });

    testWidgets('the actions are kit CTAs on their frozen keys',
        (WidgetTester tester) async {
      await pumpPrompt(tester);

      final JeebCtaButton enable = tester.widget<JeebCtaButton>(
        find.byKey(const Key('notif_perm_enable')),
      );
      final JeebCtaButton dismiss = tester.widget<JeebCtaButton>(
        find.byKey(const Key('notif_perm_dismiss')),
      );

      // M0-2 ruling 3: the affirmative act is the periwinkle pill. `accent`
      // here would be an unbudgeted orange on a screen no board tile draws.
      expect(enable.variant, JeebCtaVariant.primary);
      expect(enable.variant, isNot(JeebCtaVariant.accent));
      expect(dismiss.variant, JeebCtaVariant.text);
      expect(find.byKey(const Key('notif_perm_title')), findsOneWidget);
    });
  });
}
