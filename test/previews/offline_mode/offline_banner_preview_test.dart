// Render tests for the OfflineBanner previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// This widget is unusually hostile to a text-only suite. It has exactly TWO
// renderings — the warning MaterialBanner, or `SizedBox.shrink()` — so three of
// the five previews show the same banner and two show nothing at all. Pinning
// the banner's copy would therefore pass on five copies of the same card. Each
// state instead pins the fixture caption that names the cubit calls behind it
// (see `_OfflineBannerStage`), and the `preview specifics` group below carries
// what text cannot: the presence/absence of the banner per state, and the
// measured geometry — which is also where this widget's real defect lives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';

import '../preview_test_harness.dart';

/// The banner's own copy, spelled once so the expectations cannot drift apart.
const String _kOfflineMessage =
    'You are offline. Changes will sync when connection is restored.';

/// The rendered box of the message paragraph: its width is what the DISMISS
/// action left for the text, and its height is that width in wrapped lines
/// (20 pt per line at 1×, 30 pt at 200%).
Size _messageBox(WidgetTester tester) => tester.getSize(find.text(_kOfflineMessage));

double _bannerHeight(WidgetTester tester) =>
    tester.getSize(find.byType(MaterialBanner)).height;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OfflineBanner',
    const <String, Widget Function()>{
      'Offline · banner shown': offlineBannerOffline,
      'Offline · writes queued': offlineBannerPendingSync,
      'Dismissed this episode': offlineBannerDismissed,
      'Re-armed by a new outage': offlineBannerReArmed,
      'Online · collapsed': offlineBannerOnline,
    },
    expectedText: const <String, String>{
      // The one state that can be pinned by the widget's OWN copy.
      'Offline · banner shown': _kOfflineMessage,
      // The remaining four render either the identical banner or nothing, so
      // the caption is the only string that differs. The `preview specifics`
      // group is what proves the banner itself is in the right state.
      'Offline · writes queued': 'setOffline() + three queued writes',
      'Dismissed this episode':
          'setOffline() + dismissBanner() · hidden for this episode',
      'Re-armed by a new outage': 'offline → dismiss → online → offline again',
      'Online · collapsed': 'OfflineCubit() · online, nothing to report',
    },
  );

  group('OfflineBanner preview specifics', () {
    testWidgets('the offline preview renders one banner with a live DISMISS', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOffline);

      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      // Laid out at phone width, not the 800 pt test surface — otherwise the
      // wrapping asserted below would be measured against a layout no user has.
      expect(tester.getSize(find.byType(MaterialBanner)).width, 390);
    });

    testWidgets('both hidden states cost ZERO height, not just visibility', (
      WidgetTester tester,
    ) async {
      // A host mounts this widget unconditionally at the top of a page, so
      // "online" must leave no gap, no divider and no ghost padding behind.
      await pumpPreview(tester, offlineBannerOnline);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
      // ...and the caption is still there, so an empty card cannot be confused
      // with a preview that failed to build.
      expect(
        find.text('OfflineCubit() · online, nothing to report'),
        findsOneWidget,
      );

      await pumpPreview(tester, offlineBannerDismissed);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });

    testWidgets('JEBV4-13: dismissal is per-episode — a NEW outage re-arms it', (
      WidgetTester tester,
    ) async {
      // The two previews differ only in the transitions behind them, and the
      // difference is invisible in text: one is an empty card that is correct,
      // the other is an empty card that would be a silent regression.
      await pumpPreview(tester, offlineBannerDismissed);
      expect(find.text(_kOfflineMessage), findsNothing);

      await pumpPreview(tester, offlineBannerReArmed);
      expect(find.text(_kOfflineMessage), findsOneWidget);
      expect(find.byType(MaterialBanner), findsOneWidget);
    });

    testWidgets('the banner mirrors end-for-end in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOffline);
      final Rect enBanner = tester.getRect(find.byType(MaterialBanner));
      final double enIcon =
          tester.getCenter(find.byIcon(Icons.cloud_off)).dx - enBanner.left;

      await pumpPreview(tester, offlineBannerOffline, locale: const Locale('ar'));
      final Rect arBanner = tester.getRect(find.byType(MaterialBanner));
      final double arIcon =
          arBanner.right - tester.getCenter(find.byIcon(Icons.cloud_off)).dx;

      // Measured from the leading edge in each direction: the `cloud_off` icon
      // sits 28 pt in on BOTH sides, i.e. MaterialBanner's directional padding
      // really does swap ends. Asserted rather than eyeballed because the
      // caller passes `leading:`/`actions:` and could just as easily have built
      // its own Row with `EdgeInsets.only(left:)`.
      expect(enIcon, lessThan(enBanner.width / 2), reason: 'LTR: icon leads');
      expect(arIcon, lessThan(arBanner.width / 2), reason: 'RTL: icon trails');
      expect(enIcon, moreOrLessEquals(arIcon, epsilon: 0.5));
    });

    testWidgets('the queued-write count never reaches a pixel', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOffline);
      final Size withoutQueue = tester.getSize(find.byType(MaterialBanner));

      await pumpPreview(tester, offlineBannerPendingSync);

      // Three writes are waiting in `OfflineState.pendingSyncCount` and the
      // banner is byte-for-byte the same card: no count, no digit, not a pixel
      // of difference. Pinning current behaviour, not endorsing it — the copy
      // promises "changes will sync" without ever saying how much is at stake.
      // If someone surfaces the count, this expectation is what tells them a
      // preview and a finding are attached to the change.
      expect(tester.getSize(find.byType(MaterialBanner)), withoutQueue);
      expect(find.textContaining('3'), findsNothing);
    });

    // KNOWN DEFECT GUARD — delete/adjust when the banner stops competing with
    // its own action for width.
    //
    // MaterialBanner's single-action path lays content and actions out in ONE
    // row, and `OmdsPrimaryButton` sizes to its label and never shrinks. At
    // phone width the 62-character message is therefore squeezed into 187 pt of
    // a 390 pt banner — six wrapped lines for one sentence, a 122 pt slab.
    // `forceActionsBelow: true` is the one-line fix.
    testWidgets('at 390 pt the message gets less than half the banner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOffline);

      final Size message = _messageBox(tester);
      // Measured: 187.3 × 120 — 6 lines at 20 pt.
      expect(message.width, lessThan(195));
      expect(message.height, greaterThanOrEqualTo(120));
      expect(_bannerHeight(tester), greaterThanOrEqualTo(120));
    });

    // KNOWN DEFECT GUARD — the accessibility ceiling, and the reason
    // `offlineBannerOffline` carries `matrix: true`.
    testWidgets('at 200% text the message column gets NARROWER, not wider', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOffline);
      final double baseline = _messageBox(tester).width;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        previewCanvas(offlineBannerOffline, const Locale('en')),
      );
      await tester.pumpAndSettle();

      // Nothing throws — the `Expanded` absorbs the squeeze silently, which is
      // precisely why only a preview (or this test) catches it. The DISMISS
      // button grows with the text scale, so the message ends up with LESS room
      // than at 1×: 138 pt, eleven lines, a 332 pt banner — about 40% of a
      // phone screen spent on one sentence.
      expect(tester.takeException(), isNull);
      expect(
        _messageBox(tester).width,
        lessThan(baseline),
        reason: 'the action outgrows the text it sits beside',
      );
      expect(_messageBox(tester).height, greaterThan(300));
      expect(_bannerHeight(tester), greaterThan(320));
    });
  });
}
