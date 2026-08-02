// Render tests for the ChatFeeBanner previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// ChatFeeBanner renders ONE localized sentence whose only variable is the
// pre-formatted amount, so the `expectedText` pins below give every state a
// distinct amount. Without that, a suite over six renderings of the same band
// would pass no matter which one it actually built — and the trailing control,
// which is what the states really differ in, carries no text of its own in two
// of the three variants.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:jeeb_mobile/previews/chat/chat_fee_banner_preview.dart';

import '../preview_test_harness.dart';

/// The order-picked pill's own key, from `chat_fee_banner.dart`.
const Key _pillKey = Key('chat-fee-banner-order-picked');

/// The LBP fixture as the app's [MoneyFormat] emits it: an LTR isolate
/// (U+2066…U+2069) wrapped around the token, so the amount keeps its symbol
/// placement inside the Arabic sentence.
const String _isolatedLbp = '\u2066LBP 1,250,000.00\u2069';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatFeeBanner',
    const <String, Widget Function()>{
      'Plain notice': chatFeeBannerPlainNotice,
      'Dismissible': chatFeeBannerDismissible,
      'Order picked pill': chatFeeBannerOrderPickedPill,
      'Small phone 320dp': chatFeeBannerSmallPhoneOrderPicked,
      'Long LBP amount': chatFeeBannerLongAmount,
      'Bounded header slot': chatFeeBannerBoundedHeaderSlot,
    },
    expectedText: <String, String>{
      // One amount per state, so the pin can only be satisfied by that state.
      'Plain notice': r'Note $0.5 will be reduced from your Balance',
      'Dismissible': r'Note $0.75 will be reduced from your Balance',
      'Order picked pill': r'Note $1.25 will be reduced from your Balance',
      'Small phone 320dp': r'Note $2.50 will be reduced from your Balance',
      'Long LBP amount':
          'Note $_isolatedLbp will be reduced from your Balance',
      'Bounded header slot': r'Note $3.00 will be reduced from your Balance',
    },
  );

  group('ChatFeeBanner preview specifics', () {
    testWidgets('every preview really contains the banner', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        chatFeeBannerPlainNotice,
        chatFeeBannerDismissible,
        chatFeeBannerOrderPickedPill,
        chatFeeBannerSmallPhoneOrderPicked,
        chatFeeBannerLongAmount,
        chatFeeBannerBoundedHeaderSlot,
      ]) {
        await pumpPreview(tester, preview);

        expect(find.byType(ChatFeeBanner), findsOneWidget);
        expect(find.byKey(ChatFeeBanner.bannerKey), findsOneWidget);
      }
    });

    testWidgets('each state mounts ITS trailing control and no other', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatFeeBannerPlainNotice);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byKey(_pillKey), findsNothing);

      await pumpPreview(tester, chatFeeBannerDismissible);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byKey(_pillKey), findsNothing);

      await pumpPreview(tester, chatFeeBannerOrderPickedPill);
      expect(find.byKey(_pillKey), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('the notice is localized, never hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        chatFeeBannerPlainNotice,
        locale: const Locale('ar'),
      );

      expect(
        find.text(r'Note $0.5 will be reduced from your Balance'),
        findsNothing,
      );
      expect(find.text(r'ملاحظة: سيُخصم $0.5 من رصيدك'), findsOneWidget);
    });

    testWidgets('the dismiss × mirrors to the leading edge under AR RTL', (
      WidgetTester tester,
    ) async {
      const String english = r'Note $0.75 will be reduced from your Balance';

      await pumpPreview(tester, chatFeeBannerDismissible);
      expect(
        tester.getCenter(find.byIcon(Icons.close)).dx,
        greaterThan(tester.getCenter(find.text(english)).dx),
        reason: 'EN: the × belongs on the trailing (right) edge',
      );

      await pumpPreview(
        tester,
        chatFeeBannerDismissible,
        locale: const Locale('ar'),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.close)).dx,
        lessThan(tester.getCenter(find.byType(ChatFeeBanner)).dx),
        reason: 'AR: the × must mirror to the left half of the band',
      );
    });

    testWidgets('the LBP amount keeps its LTR isolate in both locales', (
      WidgetTester tester,
    ) async {
      // MoneyFormat wraps the token so the bidi algorithm cannot reorder `LBP`
      // away from its digits inside an RTL paragraph (JEBV4-98 / F10). The
      // isolate has to survive interpolation into the localized sentence.
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        await pumpPreview(tester, chatFeeBannerLongAmount, locale: locale);

        expect(find.textContaining(_isolatedLbp), findsOneWidget);
      }
    });

    testWidgets(
      'the order-picked pill takes more of the band than the notice at 320 dp',
      (WidgetTester tester) async {
        // Characterization pin for the layout defect the 200% rendering of this
        // preview makes fatal: the pill is a NON-FLEX child of the banner's
        // Row, so it is laid out with an unbounded main axis and claims its
        // full intrinsic width BEFORE the Expanded notice is given the
        // remainder. At the narrowest shipped width that leaves the sentence
        // less room than the button next to it.
        await pumpPreview(tester, chatFeeBannerSmallPhoneOrderPicked);

        final double pillWidth = tester.getSize(find.byKey(_pillKey)).width;
        final double noticeWidth = tester
            .getSize(
              find.text(r'Note $2.50 will be reduced from your Balance'),
            )
            .width;

        expect(pillWidth, greaterThan(noticeWidth));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the bounded header slot scrolls instead of clipping (b02)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatFeeBannerBoundedHeaderSlot);

      // The banner is the first chrome child inside a bounded, scrollable slot,
      // so an oversized band degrades to a scroll rather than an overflow. The
      // thread below it must keep its own space.
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(ChatFeeBanner), findsOneWidget);
      expect(find.byType(ChatMessageBubble), findsNWidgets(2));

      final double bannerBottom =
          tester.getBottomLeft(find.byKey(ChatFeeBanner.bannerKey)).dy;
      final double firstBubbleTop =
          tester.getTopLeft(find.byType(ChatMessageBubble).first).dy;
      expect(bannerBottom, lessThanOrEqualTo(firstBubbleTop));
      expect(tester.takeException(), isNull);
    });
  });
}
