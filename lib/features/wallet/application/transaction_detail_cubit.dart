import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/wallet_transaction_repository.dart';
import 'transaction_detail_state.dart';

/// Transaction-detail cubit (JM-056). Imports `domain/` only
/// (40_GUARDRAILS_ARCH §2.2); the abstract [WalletTransactionRepository] is
/// constructor-injected (the screen resolves `sl<WalletTransactionRepository>()`
/// — the INTEGRATOR-STUB until DI repoints to `DioWalletTransactionRepository`
/// now that W3m `GET /v1/jeeb/wallet/ledger/:id` is LIVE, CTO-D2).
class TransactionDetailCubit extends Cubit<TransactionDetailState> {
  TransactionDetailCubit({
    required WalletTransactionRepository repository,
    required String transactionId,
  })  : _repository = repository,
        _transactionId = transactionId,
        super(const TransactionDetailState());

  final WalletTransactionRepository _repository;
  final String _transactionId;

  /// Cold-entry load. Guards re-entry so a remount doesn't refetch (§2.2).
  Future<void> load() async {
    if (state.status != TransactionDetailStatus.initial) return;
    emit(state.copyWith(
      status: TransactionDetailStatus.loading,
      clearError: true,
    ));
    await _fetch();
  }

  /// Retry from the error state — does NOT guard on status (the user explicitly
  /// asked to re-run). Re-emits `loading` so the spinner returns.
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
