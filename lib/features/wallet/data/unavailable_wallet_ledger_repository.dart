import '../../../core/network/app_failure.dart';
import '../domain/wallet_ledger_repository.dart';

/// Release-path stand-in for an unregistered [WalletLedgerRepository]: fails
/// so the screen shows its error rung, never a fabricated empty ledger.
class UnavailableWalletLedgerRepository implements WalletLedgerRepository {
  const UnavailableWalletLedgerRepository();

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) {
    return Future<WalletLedgerPage>.error(
      const WalletLedgerRepositoryException(
        WalletLedgerFailure.unknown,
        cause: UnknownFailure(),
      ),
    );
  }
}
