import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../domain/wallet_ledger_repository.dart';
import 'wallet_ledger_state.dart';

class WalletLedgerCubit extends Cubit<WalletLedgerState> {
  WalletLedgerCubit({
    required WalletLedgerRepository repository,
    int pageSize = 20,
  }) : _repository = repository,
       _pageSize = pageSize,
       super(const WalletLedgerState());

  final WalletLedgerRepository _repository;
  final int _pageSize;

  /// A double pull-to-refresh must not fire two reads (§7-13b).
  bool _refreshing = false;

  /// Re-entrant from `failed`: the error rung's Retry is the only retry path.
  Future<void> load() async {
    if (state.status == WalletLedgerStatus.loading ||
        state.status == WalletLedgerStatus.loaded) {
      return;
    }
    emit(state.copyWith(status: WalletLedgerStatus.loading, clearError: true));
    try {
      final page = await _repository.fetchLedger(page: 1, pageSize: _pageSize);
      emit(
        state.copyWith(
          status: WalletLedgerStatus.loaded,
          entries: List<WalletLedgerEntry>.unmodifiable(page.entries),
          page: page.page,
          hasMore: page.hasMore,
          unrenderableCount: page.unrenderableCount,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      final failure = classifyLedgerFailure(e);
      emit(
        state.copyWith(
          status: WalletLedgerStatus.failed,
          error: _legacy(failure),
          failure: failure,
        ),
      );
    }
  }

  /// Never flips status: a failed refresh keeps the rows and raises a note.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final page = await _repository.fetchLedger(page: 1, pageSize: _pageSize);
      emit(
        state.copyWith(
          status: WalletLedgerStatus.loaded,
          entries: List<WalletLedgerEntry>.unmodifiable(page.entries),
          page: page.page,
          hasMore: page.hasMore,
          loadingMore: false,
          loadMoreError: false,
          unrenderableCount: page.unrenderableCount,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(refreshError: classifyLedgerFailure(e)));
    } finally {
      _refreshing = false;
    }
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  /// A standing [WalletLedgerState.loadMoreError] blocks re-entry, so a scroll
  /// at the foot cannot turn a persistent page failure into a retry loop.
  Future<void> loadMore() async {
    if (state.status != WalletLedgerStatus.loaded) return;
    if (!state.hasMore || state.loadingMore || state.loadMoreError) return;
    emit(state.copyWith(loadingMore: true, loadMoreError: false));
    final next = state.page + 1;
    try {
      final page = await _repository.fetchLedger(
        page: next,
        pageSize: _pageSize,
      );
      emit(
        state.copyWith(
          entries: _merge(state.entries, page.entries),
          page: page.page,
          hasMore: page.hasMore,
          loadingMore: false,
          unrenderableCount: state.unrenderableCount + page.unrenderableCount,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingMore: false,
          loadMoreError: true,
          loadMoreFailure: classifyLedgerFailure(e),
        ),
      );
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

  WalletLedgerFailure _legacy(AppFailure f) => switch (f) {
    NetworkFailure() || TimeoutFailure() => WalletLedgerFailure.network,
    UnauthorizedFailure() ||
    ForbiddenFailure() => WalletLedgerFailure.unauthorized,
    _ => WalletLedgerFailure.unknown,
  };
}

/// Unwraps the repository's own classification so the kind survives.
AppFailure classifyLedgerFailure(Object error) {
  if (error is WalletLedgerRepositoryException) {
    return error.cause ??
        switch (error.failure) {
          WalletLedgerFailure.network => networkFailureFromReachability(),
          WalletLedgerFailure.unauthorized => const UnauthorizedFailure(),
          WalletLedgerFailure.unknown => const UnknownFailure(),
        };
  }
  return AppFailure.of(error);
}
