import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/wallet_transaction_repository.dart';

enum TransactionDetailStatus { initial, loading, loaded, failed }

class TransactionDetailState extends Equatable {
  const TransactionDetailState({
    this.status = TransactionDetailStatus.initial,
    this.transaction,
    this.error,
    this.failure,
  });

  final TransactionDetailStatus status;
  final WalletTransaction? transaction;
  final WalletTransactionFailure? error;

  /// The classified failure the error rung renders; a 404 gets an exit CTA
  /// rather than a Retry that can never win.
  final AppFailure? failure;

  bool get hasTransaction => transaction != null;

  TransactionDetailState copyWith({
    TransactionDetailStatus? status,
    WalletTransaction? transaction,
    WalletTransactionFailure? error,
    AppFailure? failure,
    bool clearError = false,
  }) {
    return TransactionDetailState(
      status: status ?? this.status,
      transaction: transaction ?? this.transaction,
      error: clearError ? null : (error ?? this.error),
      failure: clearError ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, transaction, error, failure];
}
