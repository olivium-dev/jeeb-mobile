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

/// Hosts the real strip and swaps in the FRESH summary when the
class _Host extends StatefulWidget {
  const _Host({required this.wireCallback, required this.onRefreshAsked});

  final bool wireCallback;
  final VoidCallback onRefreshAsked;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
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
