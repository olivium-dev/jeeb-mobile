// Render tests for the JeeberRemovedBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/jeeber_removed_banner.dart';

import '../preview_test_harness.dart';

const String _bannerCopy = 'This request was assigned to another Jeeber.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberRemovedBanner',
    const <String, Widget Function()>{
      'Strip alone': jeeberRemovedBannerStrip,
      'Small phone 320dp': jeeberRemovedBannerSmallPhone,
      'Above frozen thread': jeeberRemovedBannerAboveFrozenThread,
      'Under fee notice': jeeberRemovedBannerUnderFeeNotice,
      'Bounded header slot': jeeberRemovedBannerBoundedHeaderSlot,
    },
    expectedText: const <String, String>{
      // The bare strip has no content but its own sentence.
      'Strip alone': _bannerCopy,
      // Each remaining state is pinned by a string ONLY that state renders:
      'Small phone 320dp': "Rana's offer was withdrawn",
      'Above frozen thread': 'I can be at the pickup in 10 minutes.',
      'Under fee notice': r'Note $0.50 will be reduced from your Balance',
      'Bounded header slot': r'Note $1.25 will be reduced from your Balance',
    },
  );

  group('JeeberRemovedBanner preview specifics', () {
    testWidgets('every preview really contains the banner', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        jeeberRemovedBannerStrip,
        jeeberRemovedBannerSmallPhone,
        jeeberRemovedBannerAboveFrozenThread,
        jeeberRemovedBannerUnderFeeNotice,
        jeeberRemovedBannerBoundedHeaderSlot,
      ]) {
        await pumpPreview(tester, preview);

        expect(find.byType(JeeberRemovedBanner), findsOneWidget);
        expect(find.byKey(const Key('jeeber-removed-banner')), findsOneWidget);
      }
    });

    testWidgets('the strip preview is the banner and nothing else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRemovedBannerStrip);

      expect(find.text(_bannerCopy), findsOneWidget);
      expect(find.byType(ChatFeeBanner), findsNothing);
      expect(find.byType(ChatMessageBubble), findsNothing);
    });

    testWidgets('the banner is localized, never hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeeberRemovedBannerStrip,
        locale: const Locale('ar'),
      );

      expect(find.text(_bannerCopy), findsNothing);
      expect(find.text('تم تخصيص هذا الطلب لموصّل آخر.'), findsOneWidget);
    });

    testWidgets('the fee-notice state stacks the fee band ABOVE the banner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRemovedBannerUnderFeeNotice);

      final double feeTop = tester.getTopLeft(find.byType(ChatFeeBanner)).dy;
      final double bannerTop =
          tester.getTopLeft(find.byType(JeeberRemovedBanner)).dy;
      expect(feeTop, lessThan(bannerTop));
    });

    testWidgets('the bounded header slot scrolls instead of clipping (b02)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberRemovedBannerBoundedHeaderSlot);

      // The chrome lives inside a scrollable bound, so an oversized stack
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(JeeberRemovedBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
