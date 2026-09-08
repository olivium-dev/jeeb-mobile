// DREC-01 — a 422 on confirm used to `return`, so the confirmed overlay and
// the rating fired on a transition the gateway had refused.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_cubit.dart';
import 'package:jeeb_mobile/features/delivery_receipt/application/delivery_receipt_state.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/widgets/receipt_confirmed_overlay.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';
import '../otp_handover/_scripted_dio.dart';

void main() {
  test('PATCH …/status → 422 throws transitionNotAllowed', () async {
    final repo = DioDeliveryReceiptRepository(
      scriptedDio((_, r) => r.failWithStatus(422)),
      originGateway: true,
    );

    await expectLater(
      repo.confirmReceipt(
        const DeliveryReceipt(
          deliveryId: 'ORD-1',
          jeeberName: 'Kamal',
          cashAmount: 9,
          currency: 'USD',
          status: 'AtDoor',
        ),
      ),
      throwsA(
        isA<DeliveryReceiptRepositoryException>().having(
          (e) => e.failure,
          'failure',
          DeliveryReceiptFailure.transitionNotAllowed,
        ),
      ),
    );
  });

  test('the cubit lands confirmStatus.failed, never succeeded', () async {
    final cubit = DeliveryReceiptCubit(
      repository: FakeDeliveryReceiptRepository(
        confirmFailure: DeliveryReceiptFailure.transitionNotAllowed,
      ),
      deliveryId: 'ORD-1',
    );
    await cubit.load();
    await cubit.confirmReceipt();

    expect(cubit.state.confirmStatus, ReceiptConfirmStatus.failed);
    expect(
      cubit.state.confirmError,
      DeliveryReceiptFailure.transitionNotAllowed,
    );
    await cubit.close();
  });

  testWidgets('the refusal renders receipt_confirm_error and NO overlay, '
      'EN + AR', (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(
          DeliveryReceiptScreen(
            deliveryId: 'ORD-1',
            repository: FakeDeliveryReceiptRepository(
              confirmFailure: DeliveryReceiptFailure.transitionNotAllowed,
            ),
          ),
          locale: locale,
        ),
      );
      // The screen animates continuously (proof hero), so it drives bounded
      // `pump()`s — never `pumpAndSettle()`.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.bySemanticsIdentifier('receipt_confirm_cta'));
      // Not pumpAndSettle: the confirm pill runs a continuous spinner while
      // the state settles, so the frame scheduler never goes quiet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.bySemanticsIdentifier('receipt_confirm_error'),
        findsOneWidget,
        reason: 'locale: $locale',
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeliveryReceiptScreen)),
      );
      expect(find.text(l10n.receiptErrorTransition), findsOneWidget);
      expect(find.byType(ReceiptConfirmedOverlay), findsNothing);
    }
  });
}
