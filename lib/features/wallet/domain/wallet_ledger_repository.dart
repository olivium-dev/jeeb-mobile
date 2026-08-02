enum WalletLedgerType {
  reserve,
  feeWon,
  released,
  refund,
  penalty,
  topup,
  gift,
  unknown,
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.sign,
    required this.ref,
    required this.timestamp,
    this.currency,
  });

  final String id;
  final WalletLedgerType type;
  final double amount;

  final int sign;

  final String ref;

  final String timestamp;

  final String? currency;
}

class WalletLedgerPage {
  const WalletLedgerPage({
    required this.entries,
    required this.page,
    required this.totalPages,
  });

  final List<WalletLedgerEntry> entries;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

enum WalletLedgerFailure { network, unauthorized, unknown }

class WalletLedgerRepositoryException implements Exception {
  const WalletLedgerRepositoryException(this.failure, [this.message]);

  final WalletLedgerFailure failure;
  final String? message;

  @override
  String toString() =>
      'WalletLedgerRepositoryException($failure, $message)';
}

abstract class WalletLedgerRepository {
  Future<WalletLedgerPage> fetchLedger({int page, int pageSize});
}
