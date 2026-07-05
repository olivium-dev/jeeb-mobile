// Isolated native UI test — DeliveryReceiptScreen (delivered-receipt-confirm,
// JM-033). The screen owns its BlocProvider and resolves a
// DeliveryReceiptRepository seam; injecting a scripted fake avoids DI/network.
// proofPhotoUrl is left null so the placeholder renders (no on-device image
// fetch). Covers the known-amount and amount-unknown (D11 degrade) branches.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';

import '../support/screen_harness.dart';

class _FakeReceiptRepo implements DeliveryReceiptRepository {
  const _FakeReceiptRepo(this._receipt);
  final DeliveryReceipt _receipt;
  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) async => _receipt;
  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async {}
}

DeliveryReceiptScreen _receipt(DeliveryReceipt r) =>
    DeliveryReceiptScreen(deliveryId: r.deliveryId, repository: _FakeReceiptRepo(r));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delivery-receipt: known cash amount (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _receipt(const DeliveryReceipt(
        deliveryId: 'del-client-001',
        jeeberName: 'Karim',
        cashAmount: 45.0,
        currency: 'USD',
        status: 'AtDoor',
      )),
      'delivery-receipt__with-amount',
    );
  });

  testWidgets('delivery-receipt: amount unknown, degraded copy (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _receipt(const DeliveryReceipt(
        deliveryId: 'del-client-002',
        jeeberName: 'Hadi',
        cashAmount: null,
        currency: 'USD',
        status: 'AtDoor',
      )),
      'delivery-receipt__no-amount',
    );
  });

  testWidgets('delivery-receipt: known cash amount (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _receipt(const DeliveryReceipt(
        deliveryId: 'del-client-001',
        jeeberName: 'Karim',
        cashAmount: 45.0,
        currency: 'USD',
        status: 'AtDoor',
      )),
      'delivery-receipt__ar',
      locale: const Locale('ar'),
    );
  });
}
