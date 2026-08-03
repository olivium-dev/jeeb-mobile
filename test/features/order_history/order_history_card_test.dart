// Widget tests for OrderHistoryCard — T11 / SW-02 money truth + SW-03 local
// time. Proves a known price renders through the single MoneyFormat rule, a
// MISSING price degrades to an em-dash (+ "Amount unavailable" a11y label) and
// never a fabricated "$0.00", and the created-at is rendered in device-local
// time (the card must call toLocal()).
//
// The redesign-2026-08 §24 group at the bottom pins the new shell contract:
// the orange frame is driven by the wire STATUS (only a physically moving
// order gets it), and the two row CTAs keep their own semantics identifiers
// through the kit card's `explicitChildNodes` protection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_card.dart';

import '../../support/sync_app_localizations.dart';

OrderSummary _order({
  int? amountMinor,
  String currency = 'USD',
  OrderRequestStatus status = OrderRequestStatus.delivered,
}) =>
    OrderSummary(
      id: 'ord-1',
      createdAt: DateTime.utc(2026, 5, 17, 10, 30),
      pickupAddress: 'Pickup',
      dropoffAddress: 'Dropoff',
      status: status,
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

Future<void> _pumpWithCtas(
  WidgetTester tester,
  OrderSummary order, {
  VoidCallback? onTrack,
  VoidCallback? onReorder,
}) async {
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(
        body: OrderHistoryCard(
          order: order,
          onTap: () {},
          onTrack: onTrack,
          onReorder: onReorder,
        ),
      ),
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

    // redesign-2026-08 §24: the meta line reads `May 17`, not a full
    // date+time stamp. The SUBJECT of this test is still `.toLocal()`.
    final expected = DateFormat.MMMd('en').format(order.createdAt.toLocal());
    expect(find.text(expected), findsOneWidget);
  });

  group('redesign-24 shell + row CTAs', () {
    for (final status in <OrderRequestStatus>[
      OrderRequestStatus.pickedUp,
      OrderRequestStatus.enRoute,
    ]) {
      testWidgets('$status is the board\'s live row (accent frame)',
          (tester) async {
        await _pump(tester, _order(amountMinor: 500, status: status));

        expect(find.byType(JeebAccentFrameCard), findsOneWidget);
      });
    }

    for (final status in <OrderRequestStatus>[
      OrderRequestStatus.pending,
      OrderRequestStatus.matched,
      OrderRequestStatus.delivered,
      OrderRequestStatus.cancelled,
      OrderRequestStatus.disputed,
      OrderRequestStatus.unknown,
    ]) {
      testWidgets('$status renders the plain outlined card', (tester) async {
        await _pump(tester, _order(amountMinor: 500, status: status));

        expect(find.byType(JeebAccentFrameCard), findsNothing);
        expect(find.byType(JeebOutlinedCard), findsOneWidget);
      });
    }

    testWidgets('a pending row still renders and carries no CTA',
        (tester) async {
      // Parity with orders_stale_status_chip_test, which pumps `pending` rows
      // into the real screen through a scripted repository.
      await _pumpWithCtas(
        tester,
        _order(amountMinor: 500, status: OrderRequestStatus.pending),
        onTrack: () {},
        onReorder: () {},
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.byType(JeebSelectChip), findsNothing);
    });

    testWidgets('a matched (assigned, not moving) row carries no CTA',
        (tester) async {
      await _pumpWithCtas(
        tester,
        _order(amountMinor: 500, status: OrderRequestStatus.matched),
        onTrack: () {},
        onReorder: () {},
      );

      expect(find.byType(JeebSelectChip), findsNothing);
    });

    testWidgets('a live row exposes a tappable Track pill by identifier',
        (tester) async {
      // Disposed inline, not via addTearDown: flutter_test runs
      // `_endOfTestVerifications` (which asserts no live SemanticsHandle) at
      // the end of the test BODY, before any tearDown fires.
      final handle = tester.ensureSemantics();
      var tracked = 0;

      await _pumpWithCtas(
        tester,
        _order(amountMinor: 500, status: OrderRequestStatus.enRoute),
        onTrack: () => tracked++,
        onReorder: () {},
      );

      // Resolvable ONLY because the kit card node sets explicitChildNodes.
      final pill = find.bySemanticsIdentifier('order_history_track_cta_ord-1');
      expect(pill, findsOneWidget);
      expect(
        find.bySemanticsIdentifier('order_history_reorder_cta_ord-1'),
        findsNothing,
      );

      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(tracked, 1);
      handle.dispose();
    });

    for (final status in <OrderRequestStatus>[
      OrderRequestStatus.delivered,
      OrderRequestStatus.cancelled,
      OrderRequestStatus.disputed,
    ]) {
      testWidgets('$status exposes the re-compose pill by identifier',
          (tester) async {
        final handle = tester.ensureSemantics();
        var reordered = 0;

        await _pumpWithCtas(
          tester,
          _order(amountMinor: 500, status: status),
          onTrack: () {},
          onReorder: () => reordered++,
        );

        final pill = find.bySemanticsIdentifier(
          'order_history_reorder_cta_ord-1',
        );
        expect(pill, findsOneWidget);
        expect(
          find.bySemanticsIdentifier('order_history_track_cta_ord-1'),
          findsNothing,
        );

        await tester.tap(pill);
        await tester.pumpAndSettle();
        expect(reordered, 1);
        handle.dispose();
      });
    }

    testWidgets('the frozen card identifier and key survive the rebuild',
        (tester) async {
      final handle = tester.ensureSemantics();

      await _pump(tester, _order(amountMinor: 500));

      expect(
        find.bySemanticsIdentifier('order_history_card_ord-1'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('order-history-card-ord-1')), findsOneWidget);
      handle.dispose();
    });
  });
}
