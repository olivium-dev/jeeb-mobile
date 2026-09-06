import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';
import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner_host.dart';

import '../preview_test_harness.dart';

/// The seat under review: the notice above the page, painted after it.
const String _kOfflineCaption = 'setOffline() · banner seated above the page';
const String _kOnlineCaption = 'OfflineCubit() · page owns the whole box';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OfflineBannerHost',
    const <String, Widget Function()>{
      'Host · notice over the page': offlineBannerHostOffline,
      'Host · online, full bleed': offlineBannerHostOnline,
    },
    expectedText: const <String, String>{
      'Host · notice over the page': _kOfflineCaption,
      'Host · online, full bleed': _kOnlineCaption,
    },
  );

  group('OfflineBannerHost preview specifics', () {
    testWidgets('the notice sits ABOVE the page, not over it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerHostOffline);

      final double bannerBottom = tester.getBottomLeft(
        find.byType(MaterialBanner),
      ).dy;
      final double pageTop = tester.getTopLeft(find.text(_kOfflineCaption)).dy;
      expect(bannerBottom, lessThanOrEqualTo(pageTop));
    });

    testWidgets('online, the host costs zero height', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offlineBannerHostOnline);

      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });
  });
}
