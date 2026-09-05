import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/wallet_transaction_repository.dart';
import 'transaction_detail_state.dart';

class TransactionDetailCubit extends Cubit<TransactionDetailState> {
  TransactionDetailCubit({
    required WalletTransactionRepository repository,
    required String transactionId,
  }) : _repository = repository,
       _transactionId = transactionId,
       super(const TransactionDetailState());

  final WalletTransactionRepository _repository;
  final String _transactionId;

  /// A double tap on the error rung's Retry must not fire two reads (§7-13b).
  bool _inFlight = false;

  Future<void> load() async {
    if (state.status != TransactionDetailStatus.initial) return;
    emit(
      state.copyWith(status: TransactionDetailStatus.loading, clearError: true),
    );
    await _fetch();
  }

  Future<void> retry() async {
    if (_inFlight) return;
    emit(
      state.copyWith(status: TransactionDetailStatus.loading, clearError: true),
    );
    await _fetch();
  }

  Future<void> _fetch() async {
    _inFlight = true;
    try {
      final txn = await _repository.fetchTransaction(_transactionId);
      emit(
        state.copyWith(
          status: TransactionDetailStatus.loaded,
          transaction: txn,
        ),
      );
    } catch (e) {
      final failure = _classify(e);
      emit(
        state.copyWith(
          status: TransactionDetailStatus.failed,
          error: e is WalletTransactionRepositoryException
              ? e.failure
              : WalletTransactionFailure.unknown,
          failure: failure,
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Unwraps the repository's own classification so the kind survives.
  AppFailure _classify(Object error) {
    if (error is WalletTransactionRepositoryException) {
      return error.cause ??
          switch (error.failure) {
            WalletTransactionFailure.network => const NetworkFailure(),
            WalletTransactionFailure.notFound => const NotFoundFailure(),
            WalletTransactionFailure.unauthorized =>
              const UnauthorizedFailure(),
            WalletTransactionFailure.unknown => const UnknownFailure(),
          };
    }
    return AppFailure.of(error);
  }
}
