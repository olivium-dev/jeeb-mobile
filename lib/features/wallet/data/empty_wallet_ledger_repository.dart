import '../domain/wallet_ledger_repository.dart';

class EmptyWalletLedgerRepository implements WalletLedgerRepository {
  const EmptyWalletLedgerRepository();

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    return const WalletLedgerPage(
      entries: <WalletLedgerEntry>[],
      page: 1,
      totalPages: 1,
    );
  }
}
