import 'package:equatable/equatable.dart';

import '../domain/wallet_transaction_repository.dart';

/// Canonical 4-state lifecycle (40_GUARDRAILS_ARCH §2/§3) for the
/// transaction-detail screen (JM-056). `loaded` + a non-null [transaction] is
/// the content state; the per-type copy + the two outbound edges
/// (`txn_detail_order_link` / `txn_detail_dispute_link`) are derived off
/// [WalletTransaction.type] in the view.
enum TransactionDetailStatus { initial, loading, loaded, failed }

class TransactionDetailState extends Equatable {
  const TransactionDetailState({
    this.status = TransactionDetailStatus.initial,
    this.transaction,
    this.error,
  });

  final TransactionDetailStatus status;
  final WalletTransaction? transaction;
  final WalletTransactionFailure? error;

  bool get hasTransaction => transaction != null;

  TransactionDetailState copyWith({
    TransactionDetailStatus? status,
    WalletTransaction? transaction,
    WalletTransactionFailure? error,
    bool clearError = false,
  }) {
    return TransactionDetailState(
      status: status ?? this.status,
      transaction: transaction ?? this.transaction,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, transaction, error];
}
