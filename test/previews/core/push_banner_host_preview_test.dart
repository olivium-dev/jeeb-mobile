// Render tests for the PushBannerHost previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/presentation/push_banner_host.dart';

import '../preview_test_harness.dart';

/// The inset `pushBannerHostUnderStatusBar` seeds, mirroring `_kStatusBarDp`.
const double _kStatusBarDp = 47;

/// The gap the widget puts between the status bar and the card.
const double _kBannerGapDp = 8;

/// The long-copy title, spelled out once so the expectation and the fixture
/// cannot drift apart silently.
const String _kLongTitle =
    'Abdulrahman Al-Muhandis sent you a message about your Beirut to Tripoli '
    'delivery';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'PushBannerHost',
    const <String, Widget Function()>{
      'Idle · no banner': pushBannerHostIdle,
      'Delivery banner': pushBannerHostDelivery,
      'Empty title fallback': pushBannerHostEmptyTitle,
      'Title only': pushBannerHostTitleOnly,
      'Long title and body': pushBannerHostLongCopy,
      'Under a status bar': pushBannerHostUnderStatusBar,
    },
    expectedText: const <String, String>{
      // No banner exists in this state, so the only thing to pin is the screen
      'Idle · no banner': 'Idle, no banner',
      'Delivery banner': 'New delivery',
      // The hardcoded fallback, not a localized string. See the group below.
      'Empty title fallback': 'Notification',
      'Title only': 'Payout method updated',
      'Long title and body': _kLongTitle,
      'Under a status bar': 'Jeeber accepted your request',
    },
  );

  group('PushBannerHost preview specifics', () {
    testWidgets('the idle preview renders no banner at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostIdle);

      // The host wraps the whole app, so "idle" must mean invisible: no card,
      expect(find.byType(Card), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Idle, no banner'), findsOneWidget);
    });

    testWidgets('a banner preview renders exactly one dismissible card', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostDelivery);

      expect(find.byType(Card), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Order #42'), findsOneWidget);
    });

    testWidgets('the title-only preview renders no body line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostTitleOnly);

      // `if (message.body.isNotEmpty)` — the one-line card is a real branch,
      expect(find.text('Payout method updated'), findsOneWidget);
      expect(find.text(''), findsNothing);
    });

    testWidgets(
      'the empty-title fallback is hardcoded English, even in Arabic',
      (WidgetTester tester) async {
        await pumpPreview(
          tester,
          pushBannerHostEmptyTitle,
          locale: const Locale('ar'),
        );

        // Pinning current behaviour, not endorsing it: `'Notification'` is a
        expect(find.text('Notification'), findsOneWidget);
        expect(find.text('Your ID check was approved'), findsOneWidget);
      },
    );

    testWidgets('the status-bar preview reserves the top inset TWICE', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostUnderStatusBar);

      // `Positioned(top: MediaQuery.padding.top + 8)` already clears the status
      final double cardTop = tester.getRect(find.byType(Card)).top;

      expect(
        cardTop,
        2 * _kStatusBarDp + _kBannerGapDp,
        reason: 'PushBannerHost double-counts the status-bar inset: the '
            'Positioned offset and the nested SafeArea each add '
            'MediaQuery.padding.top, so the banner hangs ~$_kStatusBarDp pt '
            'lower than designed on every notched device.',
      );
      expect(
        cardTop,
        greaterThan(_kStatusBarDp + _kBannerGapDp),
        reason: 'sanity: this is strictly lower than the single-inset position',
      );
    });

    testWidgets('the card mirrors end-for-end in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostDelivery);
      final double enIcon =
          tester.getCenter(find.byIcon(Icons.local_shipping_outlined)).dx;
      final double enClose = tester.getCenter(find.byIcon(Icons.close)).dx;

      await pumpPreview(
        tester,
        pushBannerHostDelivery,
        locale: const Locale('ar'),
      );
      final double arIcon =
          tester.getCenter(find.byIcon(Icons.local_shipping_outlined)).dx;
      final double arClose = tester.getCenter(find.byIcon(Icons.close)).dx;

      // The card's inner padding is `EdgeInsetsDirectional`, so the row swaps
      expect(enIcon, lessThan(enClose), reason: 'LTR: icon leads');
      expect(arIcon, greaterThan(arClose), reason: 'RTL: icon must trail');
    });

    testWidgets('the dismiss control carries NO accessible name', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than via addTearDown: the framework's
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, pushBannerHostDelivery);

      final Finder dismiss = find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(IconButton),
      );

      // Pinning current behaviour, not endorsing it. The button is tappable
      expect(tester.widget<IconButton>(dismiss).tooltip, isNull);
      expect(tester.getSemantics(dismiss).label, isEmpty);
      handle.dispose();
    });

    testWidgets('a seeded preview handler opens no transport of its own', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostDelivery);

      // The banner is on screen from the FIRST frame — i.e. the state was
      expect(find.text('New delivery'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(
        find.text('New delivery'),
        findsOneWidget,
        reason: 'autoDismiss is Duration.zero, so no timer may erase the '
            'banner mid-review or outlive the widget tree',
      );
    });
  });
}
