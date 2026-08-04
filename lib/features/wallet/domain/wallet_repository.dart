enum WalletAffordability { enough, low, empty, allReserved }

class WalletBalance {
  const WalletBalance({
    required this.availableBalance,
    required this.affordabilityState,
    required this.reservedNow,
    required this.giftCredit,
    required this.currency,
  });

  final double availableBalance;
  final WalletAffordability affordabilityState;
  final double reservedNow;
  final double giftCredit;
  final String currency;
}

enum WalletFailure { network, unauthorized, unknown }

class WalletRepositoryException implements Exception {
  const WalletRepositoryException(this.failure, [this.message]);

  final WalletFailure failure;
  final String? message;

  @override
  String toString() => 'WalletRepositoryException($failure, $message)';
}

abstract class WalletRepository {
  Future<WalletBalance> fetchBalance();
}
