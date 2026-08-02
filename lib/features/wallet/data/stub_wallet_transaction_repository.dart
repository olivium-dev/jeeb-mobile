import '../../../core/jeeb_commission.dart';
import '../domain/wallet_ledger_repository.dart' show WalletLedgerType;
import '../domain/wallet_transaction_repository.dart';

class StubWalletTransactionRepository implements WalletTransactionRepository {
  const StubWalletTransactionRepository();

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    final lower = id.toLowerCase();
    if (lower.contains('refund') || lower.contains('penalty')) {
      return WalletTransaction(
        id: id,
        type: WalletLedgerType.refund,
        amount: 6.0,
        sign: 1,
        currency: 'USD',
        timestamp: '2026-06-19T10:00:00Z',
        title: 'Dispute refund',
        ref: 'dispute-stub-$id',
        disputeId: 'dispute-client-001',
        orderId: 'req-stub-$id',
      );
    }
    return WalletTransaction(
      id: id,
      type: WalletLedgerType.feeWon,
      amount: 1.5,
      sign: -1,
      currency: 'USD',
      timestamp: '2026-06-19T10:00:00Z',
      title: 'Platform fee ($kJeebCommissionPercent%)',
      ref: 'off-stub-$id',
      offerId: 'off-stub-$id',
      orderId: 'req-stub-$id',
      pinnedPrice: 15.0,
      feeRate: kJeebCommissionRate,
    );
  }
}
