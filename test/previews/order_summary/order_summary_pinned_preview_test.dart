// Render tests for the OrderSummaryPinned previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_summary/presentation/widgets/order_summary_pinned.dart';

import '../preview_test_harness.dart';

/// Every preview in this file, by its canvas label.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Deep link · both CTAs': orderSummaryPinnedDeepLink,
  'Chat host · dense, no rating': orderSummaryPinnedChatHostDense,
  'ETA + tier pending': orderSummaryPinnedPendingFields,
  'Long name + huge price': orderSummaryPinnedLongNameHugePrice,
  'Arabic item in EN UI': orderSummaryPinnedArabicItem,
};

/// The visible copy inside one of the card's semantics containers, joined so a
/// label + value cell can be read as one string. Mirrors the helper in
String _factText(WidgetTester tester, String identifier) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier(identifier),
        matching: find.byType(Text),
      ),
    )
    .map((Text t) => t.data ?? '')
    .join('|');

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OrderSummaryPinned',
    _previews,
    expectedText: const <String, String>{
      // Each state carries its own item summary, so these five strings are
      'Deep link · both CTAs': 'Groceries from Spinneys',
      // The cold-start jeeber: the only state with no rating to show.
      'Chat host · dense, no rating': 'Yasmine Haddad',
      // The tier cell's placeholder. Exact-match, so it does not collide with
      'ETA + tier pending': 'Pending',
      // `'$amount $currency'` — toStringAsFixed(2) plus the ISO code, ungrouped.
      'Long name + huge price': '1234567.89 SYP',
      'Arabic item in EN UI': '٢ كيلو تفاح من سبينيس',
    },
  );

  group('OrderSummaryPinned preview specifics', () {
    testWidgets('the deep-link state is the one host that mounts both CTAs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedDeepLink);

      expect(
        find.bySemanticsIdentifier('order_summary_open_chat'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('order_summary_track'), findsOneWidget);
    });

    testWidgets('the chat-host state drops the self-navigating chat CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedChatHostDense);

      // A null callback removes the button entirely rather than disabling it,
      expect(find.bySemanticsIdentifier('order_summary_open_chat'), findsNothing);
      expect(find.text('Open chat'), findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_track'), findsOneWidget);
    });

    testWidgets('D6 — no score means no rating chip, name still present', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedChatHostDense);

      expect(
        find.bySemanticsIdentifier('order_summary_jeeber_name'),
        findsOneWidget,
      );
      expect(_factText(tester, 'order_summary_jeeber_name'), 'Yasmine Haddad');
      // The rating row is a FittedBox around OmdsStarRatingDisplay; with no
      expect(find.byType(FittedBox), findsNothing);
      // A null itemSummary drops the whole item fact, not just its value.
      expect(find.bySemanticsIdentifier('order_summary_item'), findsNothing);
    });

    testWidgets('an absent tier reads "Pending", never a labelled blank', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedPendingFields);

      // The tier-wire regression: the gateway serialises `tierId`, so this cell
      final String tier = _factText(tester, 'order_summary_tier');
      expect(tier, contains('Pending'));
      expect(
        tier,
        isNot('Tier|'),
        reason: 'NEGATIVE control — the pre-fix render was label + nothing',
      );
      // The ETA cell has always had its own placeholder; the point of the fix
      expect(_factText(tester, 'order_summary_eta'), contains('ETA pending'));
    });

    testWidgets('the jeeber name is clamped, so it can never wrap the row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedLongNameHugePrice);

      final Text name = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('order_summary_jeeber_name'),
          matching: find.byType(Text),
        ),
      );
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      // Clipped at paint only — nothing silently truncates the stored name.
      expect(name.data, 'Abdulrahman Al-Muhandis Al-Trabulsi');
    });

    testWidgets('D11 — every state shows the cash reminder and no fee line', (
      WidgetTester tester,
    ) async {
      // This card is CUSTOMER-facing: the COD price the customer hands over is
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        await pumpPreview(tester, entry.value);

        expect(
          find.bySemanticsIdentifier('order_summary_cash_label'),
          findsOneWidget,
          reason: entry.key,
        );
        expect(
          find.text('Pay cash on delivery'),
          findsOneWidget,
          reason: entry.key,
        );
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
