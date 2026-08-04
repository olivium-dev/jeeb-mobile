/// b02 chat-header redesign — the accessibility half of the owner's verdict.
/// Covers, for both headers:
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_pinned_summary.dart';

import 'chat_header_support.dart';

/// The Android minimum interactive size. `Sizes.fourXLarge`.
const double kMinTarget = 48.0;

/// Reads the merged semantics node for [identifier].
SemanticsNode nodeFor(WidgetTester tester, String identifier) =>
    tester.getSemantics(find.bySemanticsIdentifier(identifier));

void main() {
  setUpAll(loadArb);
  setUp(ChatHeaderExpansionStore.instance.reset);

  // A DIFFERENT order — not merely a thinner projection of [full]. The
  const sparse = OrderChatSummary(
    deliveryId: 'c1f0e2b4-8d55-4a17-9e30-5b6c7d8e9f01',
  );
  // The same order as [full] before the server has filled the detail in —
  const fullPending = OrderChatSummary(
    deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
  );
  const full = OrderChatSummary(
    deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
    orderRef: 'ORD-23470',
    priceLabel: r'$12.00',
    jeeberName: 'Kamal Hajj',
    etaMinutes: 25,
    tierId: 'express',
    statusId: 'in_transit',
    description: '2 kilos apples from Spinneys',
  );

  Future<void> pumpSummary(
    WidgetTester tester, {
    OrderChatSummary summary = full,
    VoidCallback? onViewSummary,
  }) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(themedHost(Scaffold(
      body: OrderChatPinnedSummary(
        summary: summary,
        counterpartName: 'Kamal Hajj',
        onViewSummary: onViewSummary ?? () {},
      ),
    )));
    await tester.pump();
  }

  group('collapsed by default, and the choice sticks for the session', () {
    testWidgets('a fresh header shows ONLY the collapsed row', (tester) async {
      await pumpSummary(tester);
      // Collapsed content.
      expect(find.text('ORD-23470'), findsOneWidget);
      expect(find.text('In transit'), findsOneWidget);
      expect(find.text(r'$12.00'), findsOneWidget);
      // Disclosed content — absent until asked for.
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_tier'), findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_cash_label'),
          findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_jeeber_name'),
          findsNothing);
      expect(find.bySemanticsIdentifier('order_chat_view_summary_link'),
          findsNothing);
      expect(find.bySemanticsIdentifier('order_chat_request_description'),
          findsNothing);
    });

    testWidgets('expanding reveals the rest, collapsing hides it again',
        (tester) async {
      await pumpSummary(tester);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      for (final id in const [
        'order_summary_eta',
        'order_summary_tier',
        'order_summary_cash_label',
        'order_summary_jeeber_name',
        'order_chat_view_summary_link',
        'order_chat_request_description',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsNothing);
    });

    testWidgets('the choice survives a full REMOUNT — the case local State '
        'would lose (navigate away and back)', (tester) async {
      await pumpSummary(tester);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);

      // Tear the widget down completely, then build a fresh one.
      await tester.pumpWidget(themedHost(const Scaffold(body: SizedBox())));
      await tester.pump();
      await pumpSummary(tester);
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget,
          reason: 'the session choice must be remembered across a remount');
    });

    testWidgets('the choice is per ORDER, not global', (tester) async {
      await pumpSummary(tester);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);

      await pumpSummary(tester, summary: sparse);
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsNothing,
          reason: 'a different order starts collapsed');
    });

    testWidgets('a push refetch of the SAME order does not re-collapse it',
        (tester) async {
      // Open on the pending projection (no orderRef yet), expand it, then let
      await pumpSummary(tester, summary: fullPending);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();

      await pumpSummary(tester, summary: full);
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget,
          reason: 'same delivery id — the expansion choice must survive');
    });
  });

  group('touch targets', () {
    testWidgets('the expand control is >= 48x48 and labelled, in both states',
        (tester) async {
      await pumpSummary(tester);
      final finder = find.bySemanticsIdentifier('order_chat_summary_expand');
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(kMinTarget));
      expect(tester.getSize(finder).width, greaterThanOrEqualTo(kMinTarget));

      var node = nodeFor(tester, 'order_chat_summary_expand');
      expect(node.label, 'Show order details');
      expect(node.flagsCollection.isButton, isTrue);

      await tester.tap(finder);
      await tester.pump();
      node = nodeFor(tester, 'order_chat_summary_expand');
      expect(node.label, 'Hide order details',
          reason: 'the label must describe what the tap will DO now');
    });

    testWidgets('the view-summary link is >= 48 dp tall and is a button',
        (tester) async {
      await pumpSummary(tester);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      final finder = find.bySemanticsIdentifier('order_chat_view_summary_link');
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(kMinTarget));
      expect(tester.getSize(finder).width, greaterThanOrEqualTo(kMinTarget));
      expect(
        nodeFor(tester, 'order_chat_view_summary_link').flagsCollection.isButton,
        isTrue,
      );
    });

    testWidgets('the banner dismiss is >= 48x48, labelled, and a button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(themedHost(Scaffold(
        body: OfferAcceptedBanner(
          jeeberName: 'Kamal Hajj',
          onDismiss: () {},
          onStartActiveDelivery: () {},
        ),
      )));
      await tester.pump();

      final finder = find.bySemanticsIdentifier('offer_accepted_dismiss_cta');
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(kMinTarget));
      expect(tester.getSize(finder).width, greaterThanOrEqualTo(kMinTarget));
      final node = nodeFor(tester, 'offer_accepted_dismiss_cta');
      expect(node.label, 'Dismiss');
      expect(node.flagsCollection.isButton, isTrue);

      // …and it still dismisses.
      final cta = find.bySemanticsIdentifier('chat_start_active_delivery_cta');
      expect(tester.getSize(cta).height, greaterThanOrEqualTo(kMinTarget));
    });
  });

  group('chips carry a disambiguating accessible name', () {
    testWidgets('the two unresolved chips no longer both announce "Pending"',
        (tester) async {
      await pumpSummary(tester, summary: sparse);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();

      // Visibly identical…
      expect(find.text('Pending'), findsNWidgets(3));
      // …but each announces its own field.
      expect(nodeFor(tester, 'order_summary_price').label, 'Price: Pending');
      expect(
          nodeFor(tester, 'order_summary_eta').label, 'Estimated time: Pending');
      expect(nodeFor(tester, 'order_summary_tier').label, 'Service tier: Pending');
      expect(nodeFor(tester, 'order_summary_status').label, 'Status: Matched');
    });

    testWidgets('resolved chips announce field AND value', (tester) async {
      await pumpSummary(tester);
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      expect(nodeFor(tester, 'order_summary_status').label, 'Status: In transit');
      expect(nodeFor(tester, 'order_summary_price').label, r'Price: $12.00');
      expect(nodeFor(tester, 'order_summary_eta').label, 'Estimated time: 25 min');
      expect(nodeFor(tester, 'order_summary_tier').label, 'Service tier: Express');
    });

    testWidgets('Arabic announces the Arabic field names', (tester) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(themedHost(
        const Scaffold(
          body: OrderChatPinnedSummary(
            summary: full,
            counterpartName: 'Kamal Hajj',
            onViewSummary: null,
          ),
        ),
        locale: const Locale('ar'),
      ));
      await tester.pump();
      expect(nodeFor(tester, 'order_summary_status').label,
          startsWith('الحالة: '));
      expect(nodeFor(tester, 'order_chat_summary_expand').label,
          'عرض تفاصيل الطلب');
    });
  });

  group('the compact banner keeps the information it stops painting', () {
    testWidgets('with a CTA the sentence is not painted but IS announced',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(themedHost(Scaffold(
        body: OfferAcceptedBanner(
          jeeberName: 'Kamal Hajj',
          onDismiss: () {},
          onStartActiveDelivery: () {},
        ),
      )));
      await tester.pump();
      expect(find.text('You are now chatting with your Jeeber.'), findsNothing);
      expect(
        nodeFor(tester, 'offer_accepted_banner_text').label,
        'Offer accepted! You are now chatting with your Jeeber.',
      );
    });

    testWidgets(
        'MIDNIGHT: with no CTA the sentence is STILL only announced — the '
        'demoted banner is a one-line timeline chip in every state',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(411, 914));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(themedHost(Scaffold(
        body: OfferAcceptedBanner(jeeberName: 'Kamal Hajj', onDismiss: () {}),
      )));
      await tester.pump();
      expect(find.text('You are now chatting with your Jeeber.'), findsNothing);
      expect(
        nodeFor(tester, 'offer_accepted_banner_text').label,
        'Offer accepted! You are now chatting with your Jeeber.',
      );
    });
  });
}
