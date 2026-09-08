// UX-30 — a failed warm refresh kept the rows but rendered nothing, so the
// receipt on screen silently went stale.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/delivery_receipt_screen_fixtures.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_cubit.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

Future<void> _settleBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('[$tag] a failed warm refresh renders receipt_refresh_failed '
        'over the rows and dismisses', (WidgetTester tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(
          DeliveryReceiptScreen(
            deliveryId: 'ORD-1',
            repository: DeliveryReceiptScreenFixtures.refreshFailedWarm(),
          ),
          locale: locale,
        ),
      );
      await _settleBounded(tester);

      // The cold read landed: the rows are up and the error rung is not.
      expect(find.bySemanticsIdentifier('receipt_load_error'), findsNothing);
      expect(find.bySemanticsIdentifier('receipt_refresh_failed'), findsNothing);

      final DeliveryReceiptCubit cubit =
          BlocProvider.of<DeliveryReceiptCubit>(
        tester.element(find.bySemanticsIdentifier('receipt_confirm_cta')),
      );
      await cubit.refresh();
      await _settleBounded(tester);

      expect(
        find.bySemanticsIdentifier('receipt_refresh_failed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('receipt_refresh_failed_retry_cta'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsIdentifier('receipt_refresh_failed_dismiss_cta'),
      );
      await _settleBounded(tester);
      expect(find.bySemanticsIdentifier('receipt_refresh_failed'), findsNothing);
    });
  }
}
