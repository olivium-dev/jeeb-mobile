import 'package:equatable/equatable.dart';

import '../domain/wallet_transaction_repository.dart';

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
