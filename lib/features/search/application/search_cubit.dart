import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/search_repository.dart';
import 'search_state.dart';

/// Drives free-text search (Sprint-5 Stream C). Imports `domain/` only
/// (40_GUARDRAILS_ARCH §2.2); the abstract [SearchRepository] is
/// constructor-injected (the screen resolves the LIVE [DioSearchRepository]
/// from `sl<SearchRepository>()`).
class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required SearchRepository repository})
      : _repository = repository,
        super(const SearchState());

  final SearchRepository _repository;

  /// Run a search for [rawQuery]. A blank query resets to the idle prompt
  /// (never fires a request). Otherwise flips to `loading`, then `loaded`
  /// (results may be empty → "no results") or `failed` with a typed error.
  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }
    emit(state.copyWith(
      status: SearchStatus.loading,
      query: query,
      clearError: true,
    ));
    try {
      final results = await _repository.search(query);
      emit(state.copyWith(status: SearchStatus.loaded, results: results));
    } on SearchRepositoryException catch (e) {
      emit(state.copyWith(
        status: SearchStatus.failed,
        results: const <SearchResult>[],
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: SearchStatus.failed,
        results: const <SearchResult>[],
        error: SearchFailure.unknown,
      ));
    }
  }

  /// Retry the last query (error-state CTA).
  Future<void> retry() => search(state.query);
}
