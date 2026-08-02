// Render tests for the OrderSummaryPinnedHeader previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart';

import '../preview_test_harness.dart';

/// Every preview in this file, by its canvas label.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Tracking surface': orderSummaryPinnedHeaderTracking,
  'Chat parity (both CTAs)': orderSummaryPinnedHeaderBothCtas,
  'ETA pending, no tier': orderSummaryPinnedHeaderEtaPending,
  'Unmapped tier id': orderSummaryPinnedHeaderUnmappedTier,
  'Long name + huge price': orderSummaryPinnedHeaderHugePrice,
  'Arabic item in EN UI': orderSummaryPinnedHeaderArabicItem,
};

/// The `Text` node inside one of the header's semantics containers.
Text _textUnder(WidgetTester tester, String identifier) => tester.widget<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier(identifier),
        matching: find.byType(Text),
      ),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OrderSummaryPinnedHeader',
    _previews,
    expectedText: const <String, String>{
      // The item summary — only this state carries the pharmacy line.
      'Tracking surface': 'painkillers from the pharmacy',
      // The Track CTA exists on exactly one state; the tracking surface itself
      'Chat parity (both CTAs)': 'Track order',
      // Between accept and the first GPS fix. 11 chars in EN, 25 in AR.
      'ETA pending, no tier': 'ETA pending',
      // `tierName` echoes an unknown slug back verbatim (#208).
      'Unmapped tier id': 'Tier: premium-white-glove-same-day-metropolitan',
      // `_formatPrice` = toStringAsFixed(2) + ISO code, ungrouped.
      'Long name + huge price': '1234567.89 SYP',
      'Arabic item in EN UI': '٢ كيلو تفاح من سبينيس',
    },
  );

  group('OrderSummaryPinnedHeader preview specifics', () {
    testWidgets('the tracking state omits the self-navigating Track CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedHeaderTracking);

      // JM-032: on the tracking screen "Track order" IS the current surface, so
      expect(find.bySemanticsIdentifier('order_summary_track'), findsNothing);
      expect(find.text('Track order'), findsNothing);
      expect(
        find.bySemanticsIdentifier('order_summary_open_chat'),
        findsOneWidget,
      );
    });

    testWidgets('the chat-parity state is the one that mounts both CTAs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedHeaderBothCtas);

      expect(
        find.bySemanticsIdentifier('order_summary_open_chat'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('order_summary_track'), findsOneWidget);
    });

    testWidgets('a delivery with no tier drops the node rather than blanking '
        'it', (WidgetTester tester) async {
      await pumpPreview(tester, orderSummaryPinnedHeaderEtaPending);

      expect(find.bySemanticsIdentifier('order_summary_tier'), findsNothing);
      // The ETA fact is always rendered — it has a "pending" form.
      expect(find.bySemanticsIdentifier('order_summary_eta'), findsOneWidget);
      expect(_textUnder(tester, 'order_summary_eta').data, 'ETA pending');
    });

    testWidgets('an unmapped tier id renders raw but stays clamped', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedHeaderUnmappedTier);

      // The clamp inside `_HeaderFactStrip` is what stops a single wire-sourced
      final Text tier = _textUnder(tester, 'order_summary_tier');
      expect(tier.maxLines, 1);
      expect(tier.overflow, TextOverflow.ellipsis);
      expect(tier.data, contains('premium-white-glove'));
    });

    testWidgets('the price ellipsises rather than overflowing the name row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedHeaderHugePrice);

      final Text price = _textUnder(tester, 'order_summary_price');
      expect(price.maxLines, 1);
      expect(price.overflow, TextOverflow.ellipsis);
      // The long name is still the full string in the tree, clipped only at
      expect(
        _textUnder(tester, 'order_summary_jeeber_name').data,
        'Abdulrahman Al-Muhandis Al-Trabulsi',
      );
    });

    testWidgets('D11: no state leaks a commission or finance line', (
      WidgetTester tester,
    ) async {
      // The header is CUSTOMER-facing. The cash reminder is the only money copy
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        await pumpPreview(tester, entry.value);
        expect(
          find.bySemanticsIdentifier('order_summary_cash_label'),
          findsOneWidget,
          reason: entry.key,
        );
        expect(find.text('Pay cash on delivery'), findsOneWidget,
            reason: entry.key);
        for (final String forbidden in const <String>[
          'ommission', // Commission / commission
          'Platform fee',
          'Service fee',
          'Earnings',
        ]) {
          expect(
            find.textContaining(forbidden),
            findsNothing,
            reason: '${entry.key} · $forbidden',
          );
        }
      }
    });
  });
}
