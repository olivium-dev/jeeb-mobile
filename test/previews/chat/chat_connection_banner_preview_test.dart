// Render tests for the ChatConnectionBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/chat_connection_banner.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatConnectionBanner',
    const <String, Widget Function()>{
      'Connected': chatConnectionBannerConnected,
      'Connecting': chatConnectionBannerConnecting,
      'Connected + in-flight': chatConnectionBannerConnectedPending,
      'Reconnecting + outbox': chatConnectionBannerReconnecting,
      'Offline + full outbox': chatConnectionBannerOfflineFullOutbox,
      'Offline + one pending': chatConnectionBannerOfflineOnePending,
      'Disconnected + reconnect CTA':
          chatConnectionBannerDisconnectedReconnect,
    },
    expectedText: const <String, String>{
      'Connected': 'Connected',
      'Connecting': 'Connecting…',
      'Connected + in-flight': '2 pending messages',
      'Reconnecting + outbox': '3 pending messages',
      'Offline + full outbox': '12 pending messages',
      'Offline + one pending': '1 pending message',
      'Disconnected + reconnect CTA': 'Reconnect',
    },
  );

  group('ChatConnectionBanner preview specifics', () {
    // EP-11: the strip is addressable and announces itself.
    testWidgets('the strip carries its identifier and a reconnect CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatConnectionBannerDisconnectedReconnect);

      expect(
        find.bySemanticsIdentifier('chat_connection_banner'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('chat_connection_reconnect'),
        findsOneWidget,
      );
    });

    testWidgets('a healthy strip offers no Reconnect the user cannot win', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatConnectionBannerConnected);

      expect(
        find.bySemanticsIdentifier('chat_connection_reconnect'),
        findsNothing,
      );
    });

    testWidgets('the outbox badge is absent while the outbox is empty', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatConnectionBannerConnected);

      expect(find.byKey(const Key('chat-connection-banner')), findsOneWidget);
      expect(find.byKey(const Key('chat-pending-badge')), findsNothing);
    });

    testWidgets('the outbox badge appears on the connected fill too', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatConnectionBannerConnectedPending);

      expect(find.byKey(const Key('chat-pending-badge')), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('connecting and reconnecting never share copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatConnectionBannerConnecting);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('Reconnecting…'), findsNothing);

      await pumpPreview(tester, chatConnectionBannerReconnecting);
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(find.text('Connecting…'), findsNothing);
    });

    testWidgets('Arabic singular badge uses the word form, not a digit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        chatConnectionBannerOfflineOnePending,
        locale: const Locale('ar'),
      );

      final Text badge = tester.widget<Text>(
        find.byKey(const Key('chat-pending-badge')),
      );
      expect(badge.data, isNotNull);
      expect(
        RegExp(r'[0-9٠-٩]').hasMatch(badge.data!),
        isFalse,
        reason: 'ar plural=one is a word form; a digit here means the badge '
            'interpolated a count into the wrong template.',
      );
    });

    testWidgets('the banner mirrors in Arabic', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        chatConnectionBannerOfflineFullOutbox,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(Icon))),
        TextDirection.rtl,
      );
      // Icon leads, badge trails — so the icon must sit to the RIGHT of the
      final double iconX = tester.getCenter(find.byType(Icon)).dx;
      final double badgeX =
          tester.getCenter(find.byKey(const Key('chat-pending-badge'))).dx;
      expect(iconX, greaterThan(badgeX));
    });
  });
}
