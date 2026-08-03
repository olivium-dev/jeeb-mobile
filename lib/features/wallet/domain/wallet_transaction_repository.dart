import 'wallet_ledger_repository.dart' show WalletLedgerType;

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.sign,
    required this.currency,
    required this.timestamp,
    this.title,
    this.ref,
    this.offerId,
    this.orderId,
    this.disputeId,
    this.pinnedPrice,
    this.feeRate,
  });

  final String id;
  final WalletLedgerType type;
  final double amount;

  final int sign;
  final String currency;

  final String timestamp;

  final String? title;

  final String? ref;

  final String? offerId;

  final String? orderId;

  final String? disputeId;

  final double? pinnedPrice;

  final double? feeRate;

  bool get hasOrderLink => orderId != null && orderId!.isNotEmpty;

  bool get hasDisputeLink => disputeId != null && disputeId!.isNotEmpty;

  double? get feePercent => feeRate == null ? null : feeRate! * 100;
}

enum WalletTransactionFailure { network, notFound, unauthorized, unknown }

class WalletTransactionRepositoryException implements Exception {
  const WalletTransactionRepositoryException(this.failure, [this.message]);

  final WalletTransactionFailure failure;
  final String? message;

  @override
  String toString() =>
      'WalletTransactionRepositoryException($failure, $message)';
}

abstract class WalletTransactionRepository {
  Future<WalletTransaction> fetchTransaction(String id);
}
