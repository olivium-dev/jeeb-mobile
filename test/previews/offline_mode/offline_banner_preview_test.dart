import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';

import '../preview_test_harness.dart';

/// The banner's own copy, spelled once so the expectations cannot drift apart.
const String _kOfflineMessage =
    'You are offline. Changes will sync when connection is restored.';

/// The rendered box of the message paragraph: its width is what the DISMISS
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
      'Offline · banner shown': _kOfflineMessage,
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
      expect(tester.getSize(find.byType(MaterialBanner)).width, 390);
    });

    testWidgets('both hidden states cost ZERO height, not just visibility', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOnline);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
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

      expect(tester.getSize(find.byType(MaterialBanner)), withoutQueue);
      expect(find.textContaining('3'), findsNothing);
    });

    testWidgets('at 390 pt the message gets less than half the banner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerOffline);

      final Size message = _messageBox(tester);
      expect(message.width, lessThan(195));
      expect(message.height, greaterThanOrEqualTo(120));
      expect(_bannerHeight(tester), greaterThanOrEqualTo(120));
    });

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
