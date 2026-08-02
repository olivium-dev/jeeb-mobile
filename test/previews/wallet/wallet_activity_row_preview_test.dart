// Render tests for the WalletActivityRow previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_activity_row.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'WalletActivityRow',
    const <String, Widget Function()>{
      'Fee · debit': walletActivityRowFeeDebit,
      'Starter credit · credit': walletActivityRowGiftCredit,
      'Released · no ref, no timestamp': walletActivityRowNoRefNoTime,
      'Unknown type · no currency': walletActivityRowUnknownType,
      'Top up · long ref, wide amount': walletActivityRowLongRef,
      'Refund · unparseable timestamp': walletActivityRowUnparsedTimestamp,
    },
    expectedText: const <String, String>{
      'Fee · debit': 'Ref: off-led-b',
      'Starter credit · credit': 'Ref: welcome-2026',
      'Released · no ref, no timestamp': 'Released',
      'Unknown type · no currency': 'Activity',
      'Top up · long ref, wide amount':
          'Ref: off-2026-06-18-beirut-hamra-b42-3f-abdulrahman-almuhandis-0091',
      'Refund · unparseable timestamp': '15/06/2026 09:30 AM',
    },
  );

  group('WalletActivityRow preview specifics', () {
    testWidgets('the sign is explicit on every row (JM-055 AC)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityRowFeeDebit);
      expect(find.text('-0.90 USD'), findsOneWidget);

      await pumpPreview(tester, walletActivityRowGiftCredit);
      expect(find.text('+5.00 USD'), findsOneWidget);
    });

    testWidgets('credit and debit are tinted differently', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityRowFeeDebit);
      final Color debit = tester.widget<Text>(find.text('-0.90 USD')).style!.color!;

      await pumpPreview(tester, walletActivityRowGiftCredit);
      final Color credit = tester.widget<Text>(find.text('+5.00 USD')).style!.color!;

      expect(credit, isNot(debit));
    });

    testWidgets('the relative timestamp is pinned, not wall-clock', (
      WidgetTester tester,
    ) async {
      // 2026-06-18T10:00:00Z read at the fixture's 12:00Z.
      await pumpPreview(tester, walletActivityRowFeeDebit);
      expect(find.text('2h ago'), findsOneWidget);

      // 2026-06-16T12:00:00Z at the same instant.
      await pumpPreview(tester, walletActivityRowLongRef);
      expect(find.text('2d ago'), findsOneWidget);
    });

    testWidgets('the floor row renders a label and an amount, nothing else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityRowNoRefNoTime);

      expect(find.text('Released'), findsOneWidget);
      expect(find.text('+12.50 USD'), findsOneWidget);
      // No `Ref:` sub-line and no relative-time line — both guards fail.
      expect(find.textContaining('Ref:'), findsNothing);
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('a missing currency drops the unit, not the sign', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityRowUnknownType);

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('-1.75'), findsOneWidget);
    });

    testWidgets('AR mirrors the icon and the amount', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        walletActivityRowFeeDebit,
        locale: const Locale('ar'),
      );

      final Finder row = find.byType(WalletActivityRow);
      final Rect rowRect = tester.getRect(row);
      expect(Directionality.of(tester.element(row)), TextDirection.rtl);
      // Leading icon swaps to the trailing (right) half, the signed amount to
      expect(
        tester.getRect(find.byIcon(Icons.percent_outlined)).center.dx,
        greaterThan(rowRect.center.dx),
      );
      expect(
        tester.getRect(find.text('-0.90 USD')).center.dx,
        lessThan(rowRect.center.dx),
      );
      // The type label and the `Ref:` prefix localize; the reference id itself
      expect(find.text('رسوم'), findsOneWidget);
      expect(find.text('مرجع: off-led-b'), findsOneWidget);
    });

    testWidgets('only the ref line clamps', (WidgetTester tester) async {
      await pumpPreview(tester, walletActivityRowLongRef);

      const String longRef =
          'Ref: off-2026-06-18-beirut-hamra-b42-3f-abdulrahman-almuhandis-0091';
      expect(tester.widget<Text>(find.text(longRef)).maxLines, 1);
      expect(
        tester.widget<Text>(find.text(longRef)).overflow,
        TextOverflow.ellipsis,
      );
      // The amount is neither clamped nor flexible — it takes its intrinsic
      expect(tester.widget<Text>(find.text('+1250.00 USD')).maxLines, isNull);
    });

    testWidgets('the per-row Maestro id follows the entry id', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, walletActivityRowFeeDebit);

      expect(
        find.bySemanticsIdentifier('wallet_activity_row_led-seed-fee_won'),
        findsOneWidget,
      );
    });
  });
}
