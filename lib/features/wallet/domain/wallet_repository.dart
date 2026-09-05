import '../../../core/network/app_failure.dart';

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
  const WalletRepositoryException(this.failure, {this.cause});

  final WalletFailure failure;

  /// The classified transport failure. Diagnostics + the screen's copy
  /// source; never rendered verbatim.
  final AppFailure? cause;

  @override
  String toString() => 'WalletRepositoryException(${failure.name})';
}

abstract class WalletRepository {
  Future<WalletBalance> fetchBalance();
}
