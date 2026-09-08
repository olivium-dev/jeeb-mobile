import '../../../core/network/app_failure.dart';
import '../domain/wallet_transaction_repository.dart';

/// Release-path stand-in for an unregistered [WalletTransactionRepository]:
/// fails so the screen shows its error rung, never a fabricated money row.
class UnavailableWalletTransactionRepository
    implements WalletTransactionRepository {
  const UnavailableWalletTransactionRepository();

  @override
  Future<WalletTransaction> fetchTransaction(String id) =>
      Future<WalletTransaction>.error(
        const WalletTransactionRepositoryException(
          WalletTransactionFailure.unknown,
          cause: UnknownFailure(),
        ),
      );
}
