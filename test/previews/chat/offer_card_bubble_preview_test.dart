// Render tests for the OfferCardBubble previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_bubble_timestamp.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_card_bubble.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Live offer': offerCardBubbleLiveOffer,
  'Accept in flight': offerCardBubbleAccepting,
  'Accept locked (rival winning)': offerCardBubbleAcceptLocked,
  'Declined': offerCardBubbleDeclined,
  'No note, no rating': offerCardBubbleBarePayload,
  'Long name + long note': offerCardBubbleLongContent,
  'Undated row (no clock)': offerCardBubbleUndated,
};

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OfferCardBubble',
    _previews,
    expectedText: const <String, String>{
      'Live offer': 'Kamal Hajj',
      'Accept in flight': 'Rami Aoun',
      'Accept locked (rival winning)': 'Nour Haddad',
      'Declined': 'Layla Nasr',
      // The fallback body, not a name — see the header note.
      'No note, no rating': 'ETA 12 min',
      'Long name + long note': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      'Undated row (no clock)': 'Ziad Sfeir',
    },
  );

  group('OfferCardBubble preview specifics', () {
    testWidgets('every preview renders exactly one card', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        expect(find.byType(OfferCardBubble), findsOneWidget);
      }
    });

    testWidgets('Live offer arms both actions', (WidgetTester tester) async {
      await pumpPreview(tester, offerCardBubbleLiveOffer);

      expect(
        find.byKey(const Key('chat-offer-accept-offer-preview-live')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat-offer-decline-offer-preview-live')),
        findsOneWidget,
      );
      expect(find.text('Accept Offer'), findsOneWidget);
    });

    testWidgets('Accept in flight swaps the CTA label, not the button', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardBubbleAccepting);

      // Same keyed button, different label — the only progress affordance the
      expect(
        find.byKey(const Key('chat-offer-accept-offer-preview-accepting')),
        findsOneWidget,
      );
      expect(find.text('Accepting…'), findsOneWidget);
      expect(find.text('Accept Offer'), findsNothing);
    });

    testWidgets('Declined drops the Decline button and dims the card', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardBubbleDeclined);

      // `chat_screen.dart` passes onDecline: null once the offer is declined,
      expect(
        find.byKey(const Key('chat-offer-decline-offer-preview-declined')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chat-offer-accept-offer-preview-declined')),
        findsOneWidget,
      );
      final Opacity dim = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(OfferCardBubble),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(dim.opacity, 0.4);
    });

    testWidgets('No note, no rating: ETA fallback, and no zero-star row', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, offerCardBubbleBarePayload);

      // An empty note degrades to the localized ETA line…
      expect(find.text('ETA 12 min'), findsOneWidget);
      // …and rating == 0 drops the stars entirely rather than drawing five
      expect(find.bySemanticsLabel(RegExp(r'Rated .* stars')), findsNothing);
      handle.dispose();
    });

    testWidgets('rated cards do carry the star Semantics label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, offerCardBubbleLiveOffer);

      // JEBV4-98 / F13: the stars suppress their numeric value, so the rating
      expect(
        find.bySemanticsLabel(RegExp(r'Rated 4\.8 stars')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the fee reaches a screen reader but is never drawn', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, offerCardBubbleBarePayload);

      // With no note there is no price anywhere on the card — `fee`/`currency`
      expect(find.textContaining('USD'), findsNothing);
      expect(find.textContaining('12.0'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('USD')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Undated row draws no clock', (WidgetTester tester) async {
      await pumpPreview(tester, offerCardBubbleUndated);

      // hasServerTimestamp: false means sentAt is an ordering anchor. Rendering
      expect(find.byType(ChatBubbleTimestamp), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChatBubbleTimestamp),
          matching: find.byType(Text),
        ),
        findsNothing,
      );

      // A dated sibling proves the assertion above is not vacuous.
      await pumpPreview(tester, offerCardBubbleLiveOffer);
      expect(
        find.descendant(
          of: find.byType(ChatBubbleTimestamp),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the long name truncates instead of pushing out the stars', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerCardBubbleLongContent);

      final Text name =
          tester.widget<Text>(find.text('Abdulrahman Al-Muhandis Al-Trabulsi'));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);

      // The note beside it has no maxLines — it must wrap and grow the card.
      final Text note = tester.widget<Text>(
        find.textContaining('the building has no lift'),
      );
      expect(note.maxLines, isNull);
    });

    testWidgets('the CTA labels are localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        offerCardBubbleLiveOffer,
        locale: const Locale('ar'),
      );

      expect(find.text('Accept Offer'), findsNothing);
      expect(find.text('Decline'), findsNothing);
      expect(find.text('قبول العرض'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
      // The jeeber's name is data, not copy — it stays as the server sent it.
      expect(find.text('Kamal Hajj'), findsOneWidget);
    });

    testWidgets('the empty-note ETA fallback is localized too', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        offerCardBubbleBarePayload,
        locale: const Locale('ar'),
      );

      expect(find.text('ETA 12 min'), findsNothing);
      expect(find.textContaining(RegExp(r'[؀-ۿ]')), findsWidgets);
    });

    testWidgets('the card mirrors in RTL rather than hardcoding left/right', (
      WidgetTester tester,
    ) async {
      // The card's horizontal chrome is asymmetric on purpose: the outer gutter
      await pumpPreview(tester, offerCardBubbleLiveOffer);
      final Rect ltrBubble = tester.getRect(find.byType(OfferCardBubble));
      final Rect ltrName = tester.getRect(find.text('Kamal Hajj'));
      final double leadingGap = ltrName.left - ltrBubble.left;
      final double trailingGap = ltrBubble.right - ltrName.right;

      await pumpPreview(
        tester,
        offerCardBubbleLiveOffer,
        locale: const Locale('ar'),
      );
      final Rect rtlBubble = tester.getRect(find.byType(OfferCardBubble));
      final Rect rtlName = tester.getRect(find.text('Kamal Hajj'));

      expect(rtlBubble.right - rtlName.right, closeTo(leadingGap, 0.5));
      expect(rtlName.left - rtlBubble.left, closeTo(trailingGap, 0.5));
      // Guard against a vacuous pass: a symmetric card mirrors trivially.
      expect(leadingGap, isNot(closeTo(trailingGap, 1.0)));
    });
  });
}
