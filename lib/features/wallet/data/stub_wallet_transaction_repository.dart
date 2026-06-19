import '../domain/wallet_ledger_repository.dart' show WalletLedgerType;
import '../domain/wallet_transaction_repository.dart';

/// INTEGRATOR-STUB(JM-056): the DI default for [WalletTransactionRepository]
/// until `injection_container.dart` repoints to `DioWalletTransactionRepository`
/// (CTO-D2). W3m `GET /v1/jeeb/wallet/ledger/:id` is now LIVE on :4010
/// (42_GUARDRAILS_MOCK "FINAL WAVE (W3+W4) mock closeout"), so the swap is a
/// one-line DI change — REQUESTED in 50_ROUTE_REQUESTS.md ("JM-056 DI SWAP").
///
/// DELIBERATELY a non-fake, DI-registerable stub (not a `Fake*` test seam, which
/// DO-NOT forbids in DI — 40_GUARDRAILS_ARCH §6/§12). Returns a deterministic
/// fee_won row so the detail screen renders its richest variant (exact-10% +
/// pinned price, D37) and the inbound `wallet_activity_row_<id>` edge (JM-055) is
/// reachable NOW.
class StubWalletTransactionRepository implements WalletTransactionRepository {
  const StubWalletTransactionRepository();

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    // JM-056 AC3/5: a refund/penalty transaction carries a dispute link (D2).
    // The flow pins `/wallet/transactions/txn-refund-001`, so a `refund`/
    // `penalty` id returns the refund variant (with a `disputeId` so
    // `txn_detail_dispute_link` renders); every other id returns the fee_won
    // variant (the richest D37 detail — exact-10% + pinned price, AC1/AC4).
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
      title: 'Platform fee (10%)',
      ref: 'off-stub-$id',
      offerId: 'off-stub-$id',
      orderId: 'req-stub-$id',
      pinnedPrice: 15.0,
      feeRate: 0.1,
    );
  }
}
