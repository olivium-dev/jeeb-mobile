// Render tests for the OrderSummaryPinned previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Every state pins a string only IT renders. That half is not ceremony: a suite
// that merely checks "something rendered" passes even when every preview is
// showing the same widget, which is a failure this project has already shipped
// once.
//
// What this file does NOT assert is the 200%-text overflow the previews
// document (see the JEEB PREVIEWS section of the widget). That is a live defect
// in `_PriceBlock`, and pinning the broken measurement here would turn the fix
// into a test failure.

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
/// `test/features/order_summary/tier_wire_key_test.dart`.
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
      // mutually exclusive — no two previews can satisfy each other's pin.
      'Deep link · both CTAs': 'Groceries from Spinneys',
      // The cold-start jeeber: the only state with no rating to show.
      'Chat host · dense, no rating': 'Yasmine Haddad',
      // The tier cell's placeholder. Exact-match, so it does not collide with
      // the "ETA pending" string in the cell beside it.
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
      // so the node must not exist at all — never a dead end.
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
      // score it must not be mounted at all rather than rendering "(0)".
      expect(find.byType(FittedBox), findsNothing);
      // A null itemSummary drops the whole item fact, not just its value.
      expect(find.bySemanticsIdentifier('order_summary_item'), findsNothing);
    });

    testWidgets('an absent tier reads "Pending", never a labelled blank', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderSummaryPinnedPendingFields);

      // The tier-wire regression: the gateway serialises `tierId`, so this cell
      // received '' for a long time, and `tierName('')` echoes its argument
      // back — an icon, the word "Tier", and then nothing.
      final String tier = _factText(tester, 'order_summary_tier');
      expect(tier, contains('Pending'));
      expect(
        tier,
        isNot('Tier|'),
        reason: 'NEGATIVE control — the pre-fix render was label + nothing',
      );
      // The ETA cell has always had its own placeholder; the point of the fix
      // was that the two cells now read alike instead of one being a hole.
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
      // the only money copy allowed on it beyond the reminder itself.
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
