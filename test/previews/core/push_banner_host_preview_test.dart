// Render tests for the PushBannerHost previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT string, because a
// suite that only asked "did something render?" would pass on six copies of the
// same banner — and this widget is unusually good at hiding that, since the
// fixture screen underneath renders identically in all six.
//
// The `preview specifics` group carries two things the shared harness cannot:
// the idle state is pinned by the ABSENCE of a card (there is no banner string
// to find), and the status-bar state is pinned by geometry, which is where the
// double-reserved top inset shows up as a number rather than as a hunch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/core/push_banner_host_preview.dart';

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
      // showing through — which is the assertion that matters here.
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
      // no dismiss affordance, just the screen underneath.
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
      // not the two-line card with a blank second row.
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
        // Dart literal in push_banner_host.dart with no ARB key behind it, so
        // an Arabic user gets an English title on any push that arrives without
        // one. If someone localizes it, this expectation is the thing that
        // tells them a preview and a finding are attached to the change.
        expect(find.text('Notification'), findsOneWidget);
        expect(find.text('Your ID check was approved'), findsOneWidget);
      },
    );

    testWidgets('the status-bar preview reserves the top inset TWICE', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostUnderStatusBar);

      // `Positioned(top: MediaQuery.padding.top + 8)` already clears the status
      // bar; the `SafeArea(bottom: false)` inside it then pads by
      // MediaQuery.padding.top a second time. Correct would be 47 + 8 = 55.
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
      // ends wholesale. Asserted rather than eyeballed because the enclosing
      // `Positioned` is pinned with `left`/`right`, not `start`/`end` — a pair
      // that happens to be symmetric today (12/12) and would silently stop
      // mirroring the moment someone makes it asymmetric.
      expect(enIcon, lessThan(enClose), reason: 'LTR: icon leads');
      expect(arIcon, greaterThan(arClose), reason: 'RTL: icon must trail');
    });

    testWidgets('the dismiss control carries NO accessible name', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than via addTearDown: the framework's
      // end-of-test check for leaked handles runs BEFORE tear-downs.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, pushBannerHostDelivery);

      final Finder dismiss = find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(IconButton),
      );

      // Pinning current behaviour, not endorsing it. The button is tappable
      // (SemanticsAction.tap is present) but announces as an unnamed button:
      // no `tooltip:`, no `semanticLabel:` on the Icon, no Semantics wrapper.
      // The obvious fix — `IconButton(tooltip: …)` — is the one thing this
      // widget may NOT do: `push_banner_host_overlay_test.dart` pins that the
      // host is mounted ABOVE the Navigator's Overlay, and a Tooltip mounts an
      // OverlayPortal, which is exactly the BUG-P1a crash. A `semanticLabel` on
      // the Icon (or a Semantics wrapper) is the fix that survives that
      // constraint. If someone adds one, this expectation is what tells them a
      // finding is attached to the change.
      expect(tester.widget<IconButton>(dismiss).tooltip, isNull);
      expect(tester.getSemantics(dismiss).label, isEmpty);
      handle.dispose();
    });

    testWidgets('a seeded preview handler opens no transport of its own', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pushBannerHostDelivery);

      // The banner is on screen from the FIRST frame — i.e. the state was
      // seeded synchronously rather than pushed through a stream that a preview
      // function could not have awaited. `pumpPreview` settles, so re-pumping
      // must change nothing.
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
