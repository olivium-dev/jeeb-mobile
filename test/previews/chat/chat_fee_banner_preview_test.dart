// Render tests for the ChatFeeBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_message_bubble.dart';

import '../preview_test_harness.dart';

/// The order-picked pill's own key, from `chat_fee_banner.dart`.
const Key _pillKey = Key('chat-fee-banner-order-picked');

/// The LBP fixture as the app's [MoneyFormat] emits it: an LTR isolate
/// (U+2066…U+2069) wrapped around the token, so the amount keeps its symbol
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
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        await pumpPreview(tester, chatFeeBannerLongAmount, locale: locale);

        expect(find.textContaining(_isolatedLbp), findsOneWidget);
      }
    });

    testWidgets(
      'the order-picked pill takes more of the band than the notice at 320 dp',
      (WidgetTester tester) async {
        // Characterization pin for the layout defect the 200% rendering of this
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
