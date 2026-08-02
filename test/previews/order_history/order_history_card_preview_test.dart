// Render tests for the OrderHistoryCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The pinned strings are deliberately the MONEY and STATUS tokens rather than
// the date: the card renders `createdAt.toLocal()` (SW-03), so the date label
// moves with the machine's timezone and is not assertable here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/presentation/order_history_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OrderHistoryCard',
    const <String, Widget Function()>{
      'Delivered · priced': orderHistoryCardDelivered,
      'Amount unknown (em-dash)': orderHistoryCardAmountUnknown,
      'Cancelled · zero wire amount': orderHistoryCardCancelledZeroAmount,
      'Pickup address missing': orderHistoryCardAddressMissing,
      'Unknown backend status': orderHistoryCardUnknownStatus,
      'Long addresses · LBP ceiling': orderHistoryCardLongContent,
    },
    expectedText: const <String, String>{
      // MoneyFormat wraps every token in a Unicode LTR isolate
      // (U+2066 … U+2069 — JEBV4-98 / F10), spelled as escapes so the source
      // does not carry invisible direction marks.
      'Delivered · priced': '\u2066\$1,234.00\u2069',
      'Amount unknown (em-dash)': '—',
      'Cancelled · zero wire amount': 'Cancelled',
      'Pickup address missing': 'Address unavailable',
      'Unknown backend status': 'In progress',
      'Long addresses · LBP ceiling': '\u2066LBP 1,335,000.00\u2069',
    },
  );

  group('OrderHistoryCard preview specifics', () {
    testWidgets('a MISSING amount never fabricates a \$0.00', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderHistoryCardAmountUnknown);

      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('a ZERO wire amount degrades exactly like a missing one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderHistoryCardCancelledZeroAmount);

      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('0.00'), findsNothing);
    });

    testWidgets('the em-dash carries an "Amount unavailable" a11y label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderHistoryCardAmountUnknown);

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Text && w.semanticsLabel == 'Amount unavailable',
        ),
        findsOneWidget,
      );
    });

    testWidgets('only the MISSING address leg falls back', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderHistoryCardAddressMissing);

      expect(find.text('Address unavailable'), findsOneWidget);
      expect(find.text('Sodeco Square, Beirut'), findsOneWidget);
    });

    testWidgets('an unknown status shows the localized pill, not a raw token', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderHistoryCardUnknownStatus);

      expect(find.text('In progress'), findsOneWidget);
      expect(find.textContaining('unknown'), findsNothing);
    });

    testWidgets('the LBP ceiling keeps its full amount and both addresses', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderHistoryCardLongContent);

      // The text is ellipsized on screen, but the Text widget still carries the
      // whole string — the addresses are `maxLines: 2` + ellipsis, not clipped
      // data.
      expect(find.textContaining('American University of Beirut'), findsOneWidget);
      expect(find.textContaining('beside the bakery'), findsOneWidget);
      expect(find.text('\u2066LBP 1,335,000.00\u2069'), findsOneWidget);
    });
  });
}
