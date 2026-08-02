import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/wallet_transaction_repository.dart';
import 'transaction_detail_state.dart';

class TransactionDetailCubit extends Cubit<TransactionDetailState> {
  TransactionDetailCubit({
    required WalletTransactionRepository repository,
    required String transactionId,
  })  : _repository = repository,
        _transactionId = transactionId,
        super(const TransactionDetailState());

  final WalletTransactionRepository _repository;
  final String _transactionId;

  Future<void> load() async {
    if (state.status != TransactionDetailStatus.initial) return;
    emit(state.copyWith(
      status: TransactionDetailStatus.loading,
      clearError: true,
    ));
    await _fetch();
  }

  Future<void> retry() async {
    emit(state.copyWith(
      status: TransactionDetailStatus.loading,
      clearError: true,
    ));
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final txn = await _repository.fetchTransaction(_transactionId);
      emit(state.copyWith(
        status: TransactionDetailStatus.loaded,
        transaction: txn,
      ));
    } on WalletTransactionRepositoryException catch (e) {
      emit(state.copyWith(
        status: TransactionDetailStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: TransactionDetailStatus.failed,
        error: WalletTransactionFailure.unknown,
      ));
    }
  }
}
