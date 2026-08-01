// Regression gate for the stale customer status chip, seen on real hardware
// during the live COD run of 2026-07-31.
//
// WHICH CHIP, ESTABLISHED FROM THE RUN'S OWN FRAMES (the reported symptom named
// the wrong widget):
//
//   `order_summary_status` in `OrderChatPinnedSummary` — the CUSTOMER ORDER-CHAT
//   header ("Your Jeeber"). NOT live tracking: the same run's
//   `g5/12-customer-code.png` shows the tracking stepper correctly at
//   *In transit*, and `dev-e2e/a33/G4-10-track-order.png` correctly at *At Door*.
//
//   jeeber marks Picked        21:43:43   (g5/02-picked.png)
//   jeeber marks InTransit     21:44:16   (g5/03-advanced.png)
//   customer chat header       21:44      "( Matched )"   STALE
//   customer chat header       21:46      "( Matched )"   STALE, header EXPANDED
//                                                         (g5/06-tracking-expanded.png)
//
// The stale value was "Matched" — `_statusLabel`'s `default` arm — not
// "Pending". The word "Pending" in the report is the ADJACENT tier chip in the
// same expanded header, which is a different defect (the `tierId` wire key).
//
// WHY IT WAS STALE: the chip is on the push-only status axis. The 60 s
// safety-net poll was deliberately deleted (`chat_detail_screen.dart:53-60`),
// leaving open / `didPopNext` / `onAppResumed` / a `RefreshTopic.order` push.
// The first three are attention-RETURN events and none of them fires for a
// customer who never leaves the thread, so the push is the only live trigger —
// and it did not land on that hardware.
//
// THE FIX UNDER TEST: expanding the strip is the one user-caused event on this
// screen that names this data, and the captured frame is exactly that
// interaction returning a stale chip. It now asks the host for one catch-up
// read. One shot, user-caused, no cadence — the same justification the
// screen's existing `didPopNext` catch-up carries.
//
// Controls:
//   NEGATIVE — with no callback wired (the pre-fix state) expanding fires
//              nothing and the chip stays "Matched" while the delivery is
//              really at Picked.
//   POSITIVE — with the callback wired, expanding requests exactly one refresh
//              and the chip advances "Matched" -> "Picked up" through the real
//              widget and the real ARBs.
//   BOUNDED  — collapsing does NOT request a refresh (it is not a request to
//              see this data), and expand/collapse/expand asks exactly twice.
//   WIRING   — ChatScreen forwards the callback down to the pinned strip, so
//              the host->widget plumbing cannot silently break.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_pinned_summary.dart';

import 'chat_header_support.dart';

OrderChatSummary _summary(String statusId) => OrderChatSummary(
      deliveryId: 'delivery-cod-001',
      requestId: 'req-cod-001',
      priceLabel: r'$15.00',
      jeeberName: 'Karim Driver',
      rating: 4.8,
      etaMinutes: 10,
      tierId: 'flash',
      orderRef: 'ORD-F27069',
      statusId: statusId,
      description: '2 kilos apples',
    );

/// Hosts the real strip and swaps in the FRESH summary when the widget asks for
/// a refresh — i.e. it plays the part `ChatDetailScreen._refreshSummary` plays,
/// so the assertion is about the rendered chip and not about a spy count alone.
class _Host extends StatefulWidget {
  const _Host({required this.wireCallback, required this.onRefreshAsked});

  final bool wireCallback;
  final VoidCallback onRefreshAsked;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  // What the gateway would return: the jeeber has already marked Picked.
  OrderChatSummary _current = _summary('Ordered');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrderChatPinnedSummary(
        summary: _current,
        counterpartName: 'Karim Driver',
        onViewSummary: () {},
        onSummaryAttentionRefresh: widget.wireCallback
            ? () {
                widget.onRefreshAsked();
                setState(() => _current = _summary('Picked'));
              }
            : null,
      ),
    );
  }
}

Future<void> _tapExpand(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
  await tester.pumpAndSettle();
}

String _statusChipText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier('order_summary_status'),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data ?? '')
    .join('|');

void main() {
  setUpAll(loadArb);

  setUp(() {
    // The expansion choice is process-wide and session-scoped; without this a
    // test that expands leaks "expanded" into the next one and turns a
    // collapsed-by-default assumption green for the wrong reason.
    ChatHeaderExpansionStore.instance.reset();
  });

  testWidgets(
      'NEGATIVE CONTROL — with no refresh callback (pre-fix) expanding the '
      'header changes nothing and the chip stays "Matched"', (tester) async {
    var asked = 0;
    await tester.pumpWidget(
      themedHost(_Host(wireCallback: false, onRefreshAsked: () => asked++)),
    );
    await tester.pumpAndSettle();

    expect(_statusChipText(tester), contains('Matched'));

    await _tapExpand(tester);

    expect(asked, 0, reason: 'nothing was wired, so nothing can be asked');
    expect(
      _statusChipText(tester),
      contains('Matched'),
      reason: 'this is the defect: the customer looked and learned nothing',
    );
  });

  testWidgets(
      'POSITIVE — expanding asks for one catch-up read and the chip advances '
      'Matched -> Picked up', (tester) async {
    var asked = 0;
    await tester.pumpWidget(
      themedHost(_Host(wireCallback: true, onRefreshAsked: () => asked++)),
    );
    await tester.pumpAndSettle();

    expect(_statusChipText(tester), contains('Matched'));

    await _tapExpand(tester);

    expect(asked, 1, reason: 'exactly one read, not a burst');
    expect(
      _statusChipText(tester),
      contains('Picked up'),
      reason: 'the chip must reflect where the jeeber actually is',
    );
    expect(_statusChipText(tester), isNot(contains('Matched')));
  });

  testWidgets(
      'BOUNDED — collapsing asks for nothing; expand/collapse/expand asks '
      'exactly twice', (tester) async {
    var asked = 0;
    await tester.pumpWidget(
      themedHost(_Host(wireCallback: true, onRefreshAsked: () => asked++)),
    );
    await tester.pumpAndSettle();

    await _tapExpand(tester); // expand  -> ask
    expect(asked, 1);

    await _tapExpand(tester); // collapse -> no ask
    expect(asked, 1, reason: 'collapsing is not a request to see this data');

    await _tapExpand(tester); // expand  -> ask
    expect(asked, 2);
  });

  testWidgets(
      'WIRING — ChatScreen forwards onSummaryAttentionRefresh down to the '
      'pinned strip', (tester) async {
    final gateway = FakeChatGateway(
      phase: ConversationPhase.accepted,
      history: sampleThread(),
    );
    addTearDown(gateway.dispose);

    var asked = 0;
    await tester.pumpWidget(
      themedHost(
        ChatScreen(
          deliveryId: 'delivery-cod-001',
          counterpartName: 'Karim Driver',
          gateway: gateway,
          isOrderChat: true,
          pinnedSummary: _summary('Ordered'),
          onViewSummary: () {},
          onSummaryAttentionRefresh: () => asked++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final strip = tester.widget<OrderChatPinnedSummary>(
      find.byType(OrderChatPinnedSummary),
    );
    expect(
      strip.onSummaryAttentionRefresh,
      isNotNull,
      reason: 'the host callback must survive the ChatScreen plumbing',
    );

    await _tapExpand(tester);
    expect(asked, 1);
  });
}
