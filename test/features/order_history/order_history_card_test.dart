// Widget tests for OrderHistoryCard — T11 / SW-02 money truth + SW-03 local
// time. Proves a known price renders through the single MoneyFormat rule, a
// MISSING price degrades to an em-dash (+ "Amount unavailable" a11y label) and
// never a fabricated "$0.00", and the created-at is rendered in device-local
// time (the card must call toLocal()).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_card.dart';

import '../../support/sync_app_localizations.dart';

OrderSummary _order({int? amountMinor, String currency = 'USD'}) => OrderSummary(
      id: 'ord-1',
      createdAt: DateTime.utc(2026, 5, 17, 10, 30),
      pickupAddress: 'Pickup',
      dropoffAddress: 'Dropoff',
      status: OrderRequestStatus.delivered,
      tier: OrderTier.express,
      amountMinor: amountMinor,
      currency: currency,
    );

Future<void> _pump(WidgetTester tester, OrderSummary order) async {
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(body: OrderHistoryCard(order: order, onTap: () {})),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('known amount renders through MoneyFormat (\$1,234.00)',
      (tester) async {
    await _pump(tester, _order(amountMinor: 1234_00));

    // MoneyFormat wraps the token in an LTR isolate (JEBV4-98/F10).
    expect(find.text('\u2066\$1,234.00\u2069'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('MISSING amount → em-dash, never a fabricated \$0.00',
      (tester) async {
    await _pump(tester, _order(amountMinor: null));

    expect(find.text('—'), findsOneWidget);
    // The trust-breaker: no zero is ever fabricated from a missing field.
    expect(find.textContaining('0.00'), findsNothing);
    expect(find.textContaining('\$0'), findsNothing);
  });

  testWidgets('MISSING amount carries an "Amount unavailable" a11y label',
      (tester) async {
    await _pump(tester, _order(amountMinor: null));

    // The visible glyph is an em-dash; the screen-reader label is explicit.
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.semanticsLabel == 'Amount unavailable',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a zero wire amount is treated as unknown (em-dash)',
      (tester) async {
    // A priced request is never worth 0 — a 0 means enrichment broke, so it is
    // shown as unknown, matching the receipt's hasKnownAmount contract.
    await _pump(tester, _order(amountMinor: 0));

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('created-at is rendered in device-local time (toLocal)',
      (tester) async {
    final order = _order(amountMinor: 500);
    await _pump(tester, order);

    final expected = DateFormat.yMMMd('en')
        .add_jm()
        .format(order.createdAt.toLocal());
    expect(find.text(expected), findsOneWidget);
  });
}
