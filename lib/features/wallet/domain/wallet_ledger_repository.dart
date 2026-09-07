import '../../../core/network/app_failure.dart';

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
    this.unrenderableCount = 0,
  });

  final List<WalletLedgerEntry> entries;
  final int page;
  final int totalPages;

  /// Rows the gateway sent that could not be read as money — dropped rather
  /// than rendered with a guessed sign (UX-17). Surfaced, never silent.
  final int unrenderableCount;

  bool get hasMore => page < totalPages;
}

enum WalletLedgerFailure { network, unauthorized, unknown }

class WalletLedgerRepositoryException implements Exception {
  const WalletLedgerRepositoryException(this.failure, {this.cause});

  final WalletLedgerFailure failure;

  /// The classified transport failure; never rendered verbatim.
  final AppFailure? cause;

  @override
  String toString() => 'WalletLedgerRepositoryException(${failure.name})';
}

abstract class WalletLedgerRepository {
  Future<WalletLedgerPage> fetchLedger({int page, int pageSize});
}
