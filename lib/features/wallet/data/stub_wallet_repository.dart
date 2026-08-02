import '../domain/wallet_repository.dart';

class StubWalletRepository implements WalletRepository {
  const StubWalletRepository();

  @override
  Future<WalletBalance> fetchBalance() async {
    return const WalletBalance(
      availableBalance: 120.0,
      affordabilityState: WalletAffordability.enough,
      reservedNow: 0.0,
      giftCredit: 50.0,
      currency: 'USD',
    );
  }
}
