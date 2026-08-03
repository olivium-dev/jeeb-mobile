// Render tests for the TransactionDetailScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/wallet/presentation/transaction_detail_screen.dart';

import '../preview_test_harness.dart';

/// The size the previews declare (`_transactionDetailScreenPhoneBox`). The
/// harness pumps at the `flutter_test` default of 800x600, which is wider than
const Size _canvasBox = Size(390, 844);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TransactionDetailScreen',
    const <String, Widget Function()>{
      'Fee won · 10% + pinned price': transactionDetailScreenFeeWon,
      'Refund · dispute + order links': transactionDetailScreenRefund,
      'Reserve · GUID reference': transactionDetailScreenLongReference,
      'Gift · minimal row': transactionDetailScreenGiftMinimal,
      'Unknown type · generic copy': transactionDetailScreenUnknownType,
      'Error · not found': transactionDetailScreenErrorNotFound,
      'Error · network': transactionDetailScreenErrorNetwork,
    },
    expectedText: const <String, String>{
      // The pinned accepted price (D37). `10%` would not do — the fee RATE
      'Fee won · 10% + pinned price': '15.00 USD',
      // The dispute reference value, which no other fixture carries.
      'Refund · dispute + order links': 'dispute-client-001',
      // The reference the row exists for.
      'Reserve · GUID reference': 'off-9f3c1d2e-4b7a-11f0-9cd6-0242ac120002',
      // The only per-type heading no other fixture reaches.
      'Gift · minimal row': 'Starter credit',
      // The reference — NOT the heading. An `unknown` row's heading is the
      'Unknown type · generic copy': 'adj-manual-7781',
      // The one failure with its own copy...
      'Error · not found': 'This transaction could not be found.',
      // ...and the generic fold the other three land in. Note the typographic
      'Error · network':
          'We couldn’t load this transaction. Please try again.',
    },
  );

  // The loading sub-state is an indeterminate `CircularProgressIndicator`
  group('TransactionDetailScreen previews · Loading · spinner', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(transactionDetailScreenLoading, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      // The spinner is up...
      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and neither settled surface is. That combination is true of no
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    // The state is escapable from the first frame: the app bar is built above
    testWidgets('the back affordance exists during the load', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  // The defect these previews exist for, and the reason this group resizes the
  group('TransactionDetailScreen previews · Reserve · GUID reference', () {
    Future<void> pumpAtCanvasWidth(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(_canvasBox);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        previewCanvas(transactionDetailScreenLongReference, locale),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a GUID reference overflows the detail row at phone width', (
      WidgetTester tester,
    ) async {
      await pumpAtCanvasWidth(tester);

      // The reference is on screen (the value is never truncated — that is the
      expect(
        find.text('off-9f3c1d2e-4b7a-11f0-9cd6-0242ac120002'),
        findsOneWidget,
      );
      // ...and the row it sits in reports the overflow. `takeException`
      final Object? overflow = tester.takeException();
      expect(overflow, isNotNull);
      expect(
        overflow.toString(),
        contains('overflowed'),
        reason: 'the reference row should overflow at 390 pt — if this stops '
            'being true, _DetailRow learned to constrain its value and this '
            'group should become the regression guard for that fix',
      );
    });

    testWidgets('the same preview does not overflow at the 800 pt default', (
      WidgetTester tester,
    ) async {
      // Not a duplicate of the shared suite: this pins WHY the defect is
      await pumpPreview(tester, transactionDetailScreenLongReference);

      expect(tester.takeException(), isNull);
    });
  });

  group('TransactionDetailScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree

    testWidgets('the fee-won preview shows the JM-056 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenFeeWon);

      expect(find.bySemanticsIdentifier('txn_detail_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('txn_detail_amount'), findsOneWidget);
      // D37: the EXACT rate, derived from the app-wide commission constant,
      expect(find.bySemanticsIdentifier('txn_detail_fee_rate'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('txn_detail_pinned_price'),
        findsOneWidget,
      );
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('-1.50 USD'), findsOneWidget);
      // A won fee carries an order and no dispute.
      expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsOneWidget);
      expect(find.bySemanticsIdentifier('txn_detail_dispute_link'), findsNothing);
    });

    // The finding. `transaction_detail_screen_test.dart` asserts a refund shows
    testWidgets('a refund carrying an orderId renders BOTH outbound edges', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenRefund);

      expect(
        find.bySemanticsIdentifier('txn_detail_dispute_link'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('txn_detail_order_link'),
        findsOneWidget,
        reason: 'the screen doc says the order link is for reserve / fee_won / '
            'released rows only',
      );
      // A refund is not a fee row, so no fee breakdown either way.
      expect(find.bySemanticsIdentifier('txn_detail_fee_rate'), findsNothing);
      expect(find.bySemanticsIdentifier('txn_detail_pinned_price'), findsNothing);
      // Credit, so the sign flips.
      expect(find.text('+6.00 USD'), findsOneWidget);
    });

    // The other finding. The row carries a server-supplied title and the
    testWidgets('an unknown type drops the server title for generic copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenUnknownType);

      expect(find.text('Manual ops adjustment'), findsNothing);
      expect(find.text('Transaction'), findsOneWidget);
      expect(
        find.text('The full breakdown of this wallet movement.'),
        findsOneWidget,
      );
      // Nothing else to hold on to: no links, no fee breakdown.
      expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing);
      expect(find.bySemanticsIdentifier('txn_detail_dispute_link'), findsNothing);
    });

    testWidgets('the minimal row drops the date and every optional field', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenGiftMinimal);

      expect(find.text('Starter credit'), findsOneWidget);
      expect(find.text('+50.00 USD'), findsOneWidget);
      // `if (txn.timestamp.isNotEmpty)` — an empty instant hides the row
      expect(find.text('Date'), findsNothing);
      expect(find.text('Reference'), findsNothing);
      expect(find.bySemanticsIdentifier('txn_detail_order_ref'), findsNothing);
      expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing);
      expect(find.bySemanticsIdentifier('txn_detail_dispute_link'), findsNothing);
    });

    testWidgets('the two error previews render DIFFERENT copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenErrorNotFound);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('This transaction could not be found.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The root Semantics survives a failed load — the screen is still a
      expect(find.bySemanticsIdentifier('txn_detail_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('txn_detail_amount'), findsNothing);
    });

    testWidgets('the network error folds into the generic message', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenErrorNetwork);

      expect(
        find.text('We couldn’t load this transaction. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('This transaction could not be found.'), findsNothing);
    });

    // The Router the preview host adds is not decoration: without it every
    testWidgets('tapping the order link routes with the row order id', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenFeeWon);

      await tester.tap(find.bySemanticsIdentifier('txn_detail_order_link'));
      await tester.pumpAndSettle();

      expect(find.text('order-summary (preview stand-in)'), findsOneWidget);
      expect(find.text('id: req-stub-1001'), findsOneWidget);
    });

    testWidgets('tapping the dispute link routes with the dispute id', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transactionDetailScreenRefund);

      await tester.tap(find.bySemanticsIdentifier('txn_detail_dispute_link'));
      await tester.pumpAndSettle();

      expect(find.text('escalate (preview stand-in)'), findsOneWidget);
      // The route is keyed on a delivery/order id but W3m only supplies the
      expect(find.text('id: dispute-client-001'), findsOneWidget);
    });
  });
}
