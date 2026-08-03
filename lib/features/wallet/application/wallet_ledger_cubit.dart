import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/wallet_ledger_repository.dart';
import 'wallet_ledger_state.dart';

class WalletLedgerCubit extends Cubit<WalletLedgerState> {
  WalletLedgerCubit({
    required WalletLedgerRepository repository,
    int pageSize = 20,
  })  : _repository = repository,
        _pageSize = pageSize,
        super(const WalletLedgerState());

  final WalletLedgerRepository _repository;
  final int _pageSize;

  Future<void> load() async {
    if (state.status != WalletLedgerStatus.initial) return;
    emit(state.copyWith(status: WalletLedgerStatus.loading, clearError: true));
    try {
      final page = await _repository.fetchLedger(page: 1, pageSize: _pageSize);
      emit(state.copyWith(
        status: WalletLedgerStatus.loaded,
        entries: List<WalletLedgerEntry>.unmodifiable(page.entries),
        page: page.page,
        hasMore: page.hasMore,
      ));
    } on WalletLedgerRepositoryException catch (e) {
      emit(state.copyWith(
        status: WalletLedgerStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: WalletLedgerStatus.failed,
        error: WalletLedgerFailure.unknown,
      ));
    }
  }

  Future<void> refresh() async {
    try {
      final page = await _repository.fetchLedger(page: 1, pageSize: _pageSize);
      emit(state.copyWith(
        status: WalletLedgerStatus.loaded,
        entries: List<WalletLedgerEntry>.unmodifiable(page.entries),
        page: page.page,
        hasMore: page.hasMore,
        loadingMore: false,
        loadMoreError: false,
        clearError: true,
      ));
    } on WalletLedgerRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: WalletLedgerFailure.unknown));
    }
  }

  Future<void> loadMore() async {
    if (state.status != WalletLedgerStatus.loaded) return;
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true, loadMoreError: false));
    final next = state.page + 1;
    try {
      final page = await _repository.fetchLedger(
        page: next,
        pageSize: _pageSize,
      );
      emit(state.copyWith(
        entries: _merge(state.entries, page.entries),
        page: page.page,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } on WalletLedgerRepositoryException catch (_) {
      emit(state.copyWith(loadingMore: false, loadMoreError: true));
    } catch (_) {
      emit(state.copyWith(loadingMore: false, loadMoreError: true));
    }
  }

  Future<void> retryLoadMore() async {
    if (!state.loadMoreError) return;
    emit(state.copyWith(loadMoreError: false));
    await loadMore();
  }

  List<WalletLedgerEntry> _merge(
    List<WalletLedgerEntry> existing,
    List<WalletLedgerEntry> incoming,
  ) {
    final seen = existing.map((e) => e.id).toSet();
    final out = List<WalletLedgerEntry>.of(existing);
    for (final e in incoming) {
      if (e.id.isEmpty || seen.add(e.id)) out.add(e);
    }
    return List<WalletLedgerEntry>.unmodifiable(out);
  }
}
