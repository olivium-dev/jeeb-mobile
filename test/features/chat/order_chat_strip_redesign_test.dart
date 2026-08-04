/// redesign-2026-08 screen 21 — the two net-new pieces of the thread chrome:
/// the navy strip's white `Track` pill, and the timestamped system chip.
///
/// Both are gated on data the wire may not carry, and both would be a lie if
/// they were not: a `Track` pill with no delivery to track is a dead end, and a
/// clock printed over a row the server never dated is a fabricated fact.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_pinned_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/system_message_bubble.dart';

import 'chat_header_support.dart';

const _trackCta = 'order_chat_track_cta';
const _uuid = '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6';

const _summary = OrderChatSummary(
  deliveryId: _uuid,
  orderRef: 'ORD-23470',
  priceLabel: r'$12.00',
  jeeberName: 'Kamal Hajj',
  statusId: 'in_transit',
);

Future<void> _pumpStrip(
  WidgetTester tester, {
  required OrderChatSummary summary,
  VoidCallback? onTrack,
}) async {
  await tester.pumpWidget(themedHost(Scaffold(
    body: OrderChatPinnedSummary(
      summary: summary,
      counterpartName: 'Kamal Hajj',
      onViewSummary: () {},
      onTrack: onTrack,
    ),
  )));
  await tester.pump();
}

void main() {
  setUpAll(loadArb);
  setUp(ChatHeaderExpansionStore.instance.reset);

  group('the Track pill is never a dead end', () {
    testWidgets('absent when no tracking route is wired', (tester) async {
      await _pumpStrip(tester, summary: _summary);
      expect(find.bySemanticsIdentifier(_trackCta), findsNothing);
    });

    testWidgets('absent when the summary carries no delivery id',
        (tester) async {
      await _pumpStrip(
        tester,
        summary: const OrderChatSummary(
          deliveryId: '',
          requestId: 'req-1',
          orderRef: 'ORD-23470',
          priceLabel: r'$12.00',
          statusId: 'in_transit',
        ),
        onTrack: () {},
      );
      expect(
        find.bySemanticsIdentifier(_trackCta),
        findsNothing,
        reason: 'there is nothing to track — the pill must not render',
      );
    });

    testWidgets('present and tappable on a resolved accepted order',
        (tester) async {
      var tapped = 0;
      await _pumpStrip(tester, summary: _summary, onTrack: () => tapped++);

      final pill = find.bySemanticsIdentifier(_trackCta);
      expect(pill, findsOneWidget);
      expect(
        tester.getSemantics(pill),
        containsSemantics(identifier: _trackCta, isButton: true),
      );
      // 48 dp floor: the visible pill is ~26 dp tall, the TARGET is not.
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(48));

      await tester.tap(pill);
      expect(tapped, 1);
    });

    testWidgets('rides in the COLLAPSED row — it is the board\'s one-liner',
        (tester) async {
      await _pumpStrip(tester, summary: _summary, onTrack: () {});
      // Still collapsed: the disclosed field ids are absent, the pill is not.
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsNothing);
      expect(find.bySemanticsIdentifier(_trackCta), findsOneWidget);
    });
  });

  group('the system chip prints a clock only when the server sent one', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required bool dated,
    }) async {
      await tester.pumpWidget(themedHost(Scaffold(
        body: SystemMessageBubble(
          message: DeliveryChatMessage.system(
            id: 's1',
            sentAt: DateTime(2026, 8, 3, 9, 12),
            text: 'Karim is on the way',
            hasServerTimestamp: dated,
          ),
        ),
      )));
      await tester.pump();
    }

    testWidgets('dated row → "<event> · HH:mm"', (tester) async {
      await pumpChip(tester, dated: true);
      expect(find.text('Karim is on the way · 09:12'), findsOneWidget);
    });

    testWidgets('undated row → the event ALONE, never 1970 and never 00:00',
        (tester) async {
      await pumpChip(tester, dated: false);
      expect(find.text('Karim is on the way'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });
  });
}
