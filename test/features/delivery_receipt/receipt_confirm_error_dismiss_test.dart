// DREC-02 — `acknowledgeConfirmError()` existed and was never called, so the
// confirm-error line had no way off the screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_cubit.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_state.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

Future<void> _settleBounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the dismiss control clears receipt_confirm_error, EN + AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(
          DeliveryReceiptScreen(
            deliveryId: 'ORD-1',
            repository: FakeDeliveryReceiptRepository(
              confirmFailure: DeliveryReceiptFailure.network,
            ),
          ),
          locale: locale,
        ),
      );
      await _settleBounded(tester);

      await tester.tap(find.bySemanticsIdentifier('receipt_confirm_cta'));
      await _settleBounded(tester);
      expect(
        find.bySemanticsIdentifier('receipt_confirm_error'),
        findsOneWidget,
        reason: 'locale: $locale',
      );

      await tester.tap(
        find.bySemanticsIdentifier('receipt_confirm_error_dismiss_cta'),
      );
      await _settleBounded(tester);

      expect(
        find.bySemanticsIdentifier('receipt_confirm_error'),
        findsNothing,
        reason: 'locale: $locale',
      );
    }
  });

  test('acknowledgeConfirmError returns the confirm axis to idle', () async {
    final cubit = DeliveryReceiptCubit(
      repository: FakeDeliveryReceiptRepository(
        confirmFailure: DeliveryReceiptFailure.network,
      ),
      deliveryId: 'ORD-1',
    );
    await cubit.load();
    await cubit.confirmReceipt();
    expect(cubit.state.confirmStatus, ReceiptConfirmStatus.failed);

    cubit.acknowledgeConfirmError();
    expect(cubit.state.confirmStatus, ReceiptConfirmStatus.idle);
    expect(cubit.state.confirmError, isNull);
    await cubit.close();
  });
}
