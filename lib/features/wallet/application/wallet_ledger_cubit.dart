import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/wallet_ledger_repository.dart';
import 'wallet_ledger_state.dart';

/// Drives wallet-activity-list (JM-055). Imports `domain/` only
/// (40_GUARDRAILS_ARCH §2.2); the abstract [WalletLedgerRepository] is
/// constructor-injected (the screen resolves the LIVE `DioWalletLedgerRepository`
/// from `sl<WalletLedgerRepository>()` — W2m `GET /v1/jeeb/wallet/ledger` is
/// mock-ready on :4010, 42_GUARDRAILS_MOCK "W2 mock closeout").
///
/// Responsibilities:
///  - cold-load the first ledger page (newest-first, paginated W2m envelope),
///  - pull-to-refresh: re-fetch page 1 without flipping to a full-screen spinner
///    (the UI shows the pull indicator, §2.2),
///  - load-more: fetch the next page on scroll-end and APPEND it (infinite
///    scroll, JM-055 AC) — de-duped by row id, single-flight (a second
///    scroll-end while a page is in flight is a no-op), and a failure is held as
///    a soft footer error that leaves the loaded rows intact.
class WalletLedgerCubit extends Cubit<WalletLedgerState> {
  WalletLedgerCubit({
    required WalletLedgerRepository repository,
    int pageSize = 20,
  })  : _repository = repository,
        _pageSize = pageSize,
        super(const WalletLedgerState());

  final WalletLedgerRepository _repository;
  final int _pageSize;

  /// Cold-entry load (page 1). Guards re-entry so a remount doesn't refetch
  /// (§2.2).
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

  /// Pull-to-refresh — re-fetches page 1 and REPLACES the list (the freshest
  /// page wins). Does NOT flip `status` to `loading` (§2.2). Resets the paging
  /// cursor + clears any soft load-more error.
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

  /// Fetch the next page and APPEND it (infinite scroll). Single-flight: a no-op
  /// when not loaded, when there is no further page, or when a fetch is already
  /// in flight. A failure surfaces as the soft [WalletLedgerState.loadMoreError]
  /// footer (the loaded rows stay) and can be retried by [retryLoadMore].
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

  /// Retry the failed next-page fetch (clears the soft footer error, re-runs
  /// [loadMore]).
  Future<void> retryLoadMore() async {
    if (!state.loadMoreError) return;
    emit(state.copyWith(loadMoreError: false));
    await loadMore();
  }

  /// Append [incoming] to [existing], dropping rows whose id is already present
  /// (a defensive de-dupe — a backend that re-emits a boundary row on the next
  /// page must never double-render it). Returns an unmodifiable list — the cubit
  /// owns the order (§2.1).
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
