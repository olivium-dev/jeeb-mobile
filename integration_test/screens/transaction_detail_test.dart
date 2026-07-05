// Isolated native UI test — TransactionDetailScreen (transaction-detail,
// JM-056). The screen builds a TransactionDetailCubit off the `repository` seam
// and calls load(), so injecting a scripted row avoids DI/network. Covers the
// fee-won breakdown (exact 10% + pinned price + order link), the refund/penalty
// dispute-link variant, and the fee-won row again in Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/transaction_detail_screen.dart';

import '../support/screen_harness.dart';

/// In-memory transaction repo serving one fixed row. Inlined so the integration
/// test never reaches into test/support/.
class _FakeTxnRepository implements WalletTransactionRepository {
  _FakeTxnRepository(this._txn);

  final WalletTransaction _txn;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async => _txn;
}

WalletTransaction _txn({
  required WalletLedgerType type,
  int sign = -1,
  double amount = 1.5,
  String? offerId,
  String? orderId,
  String? disputeId,
  double? pinnedPrice,
  double? feeRate,
}) =>
    WalletTransaction(
      id: 'led-1',
      type: type,
      amount: amount,
      sign: sign,
      currency: 'USD',
      timestamp: '2026-06-19T10:00:00Z',
      ref: offerId ?? disputeId,
      offerId: offerId,
      orderId: orderId,
      disputeId: disputeId,
      pinnedPrice: pinnedPrice,
      feeRate: feeRate,
    );

TransactionDetailScreen _screen(WalletTransaction txn) => TransactionDetailScreen(
      transactionId: txn.id,
      repository: _FakeTxnRepository(txn),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('transaction-detail: fee-won breakdown + order link (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_txn(
        type: WalletLedgerType.feeWon,
        amount: 1.5,
        orderId: 'req-1',
        offerId: 'off-1',
        pinnedPrice: 15,
        feeRate: 0.1,
      )),
      'transaction-detail__fee-won',
    );
  });

  testWidgets('transaction-detail: refund with dispute link (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_txn(
        type: WalletLedgerType.refund,
        sign: 1,
        amount: 9,
        disputeId: 'dispute-1',
      )),
      'transaction-detail__refund',
    );
  });

  testWidgets('transaction-detail: fee-won breakdown (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(_txn(
        type: WalletLedgerType.feeWon,
        amount: 1.5,
        orderId: 'req-1',
        offerId: 'off-1',
        pinnedPrice: 15,
        feeRate: 0.1,
      )),
      'transaction-detail__ar',
      locale: const Locale('ar'),
    );
  });
}
