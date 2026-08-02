// Render tests for the OfferAcceptedBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';

import '../preview_test_harness.dart';

/// The banner's own root, as `chat_header_contrast_test.dart` addresses it.
const Key _bannerKey = Key('offer-accepted-banner');

/// Jeeber-only CTA (active delivery) and client-only CTA (live tracking).
const Key _startCtaKey = Key('chat-start-active-delivery-cta');
const Key _trackCtaKey = Key('offer-accepted-track-cta');

/// Painted only when NO CTA shares the row (`showBody: !hasCta`); always
/// present on the row's accessible name.
const String _supportingSentence = 'You are now chatting with your Jeeber.';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OfferAcceptedBanner',
    const <String, Widget Function()>{
      'Client · no CTA yet': offerAcceptedBannerClientNoCta,
      'Jeeber · start delivery': offerAcceptedBannerJeeberStartDelivery,
      'Client · track order': offerAcceptedBannerClientTrackOrder,
      'Small phone 320dp': offerAcceptedBannerSmallPhone,
      'Both CTAs': offerAcceptedBannerBothCtas,
    },
    expectedText: const <String, String>{
      // The only state with room to paint the supporting sentence.
      'Client · no CTA yet': _supportingSentence,
      // Every other state is pinned by the gating system notice, which names a
      'Jeeber · start delivery': "Rana's offer was accepted",
      'Client · track order': "Nour's offer was accepted",
      'Small phone 320dp': "Ziad's offer was accepted",
      'Both CTAs': "Layla's offer was accepted",
    },
  );

  group('OfferAcceptedBanner preview specifics', () {
    testWidgets('every preview really contains the banner', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        offerAcceptedBannerClientNoCta,
        offerAcceptedBannerJeeberStartDelivery,
        offerAcceptedBannerClientTrackOrder,
        offerAcceptedBannerSmallPhone,
        offerAcceptedBannerBothCtas,
      ]) {
        await pumpPreview(tester, preview);

        expect(find.byType(OfferAcceptedBanner), findsOneWidget);
        expect(find.byKey(_bannerKey), findsOneWidget);
        // The title is the one string no state may drop.
        expect(find.text('Offer accepted!'), findsOneWidget);
      }
    });

    testWidgets('the CTA-less state offers NO route out (G5 dead-end guard)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptedBannerClientNoCta);

      // No delivery id yet -> no CTA at all, rather than a button to nowhere.
      expect(find.byKey(_startCtaKey), findsNothing);
      expect(find.byKey(_trackCtaKey), findsNothing);
      // ...which is exactly why this state has room for the sentence.
      expect(find.text(_supportingSentence), findsOneWidget);
    });

    testWidgets('the Jeeber state wires the start CTA and only that one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptedBannerJeeberStartDelivery);

      expect(find.byKey(_startCtaKey), findsOneWidget);
      expect(find.text('Start delivery'), findsOneWidget);
      expect(find.byKey(_trackCtaKey), findsNothing);
      expect(find.text('Track my order'), findsNothing);
      // It is the state that stacks the navy fee band on the success band.
      expect(find.byType(ChatFeeBanner), findsOneWidget);
    });

    testWidgets('the client state wires the track CTA and only that one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptedBannerClientTrackOrder);

      expect(find.byKey(_trackCtaKey), findsOneWidget);
      expect(find.text('Track my order'), findsOneWidget);
      expect(find.byKey(_startCtaKey), findsNothing);
      expect(find.byType(ChatFeeBanner), findsNothing);
    });

    testWidgets('the widest state really carries BOTH CTAs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptedBannerBothCtas);

      expect(find.byKey(_startCtaKey), findsOneWidget);
      expect(find.byKey(_trackCtaKey), findsOneWidget);
      expect(find.text('Start delivery'), findsOneWidget);
      expect(find.text('Track my order'), findsOneWidget);
      // Two CTAs plus the dismiss target, and still no overflow stripe.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the small-phone state is really clamped to 320 dp', (
      WidgetTester tester,
    ) async {
      // pumpPreview uses the default 800x600 viewport and ignores
      await pumpPreview(tester, offerAcceptedBannerSmallPhone);

      expect(tester.getSize(find.byKey(_bannerKey)).width, 320);
      expect(find.byKey(_trackCtaKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 320 dp is already narrow enough that the CTA takes a run of its own:
      expect(
        tester.getSize(find.byKey(_bannerKey)).height,
        greaterThan(64),
        reason: 'the CTA should have wrapped to a second run at 320 dp',
      );
    });

    testWidgets('a CTA hides the sentence from the paint, never from the '
        'screen reader', (WidgetTester tester) async {
      await pumpPreview(tester, offerAcceptedBannerJeeberStartDelivery);

      expect(find.text(_supportingSentence), findsNothing);
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('offer_accepted_banner_text'),
      );
      expect(node.label, 'Offer accepted! $_supportingSentence');
    });

    testWidgets('the banner localizes, never hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        offerAcceptedBannerClientTrackOrder,
        locale: const Locale('ar'),
      );

      expect(find.text('تم قبول العرض!'), findsOneWidget);
      expect(find.text('تتبّع طلبي'), findsOneWidget);
      expect(find.text('Offer accepted!'), findsNothing);
      expect(find.text('Track my order'), findsNothing);
    });
  });
}
