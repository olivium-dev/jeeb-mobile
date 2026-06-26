import 'package:equatable/equatable.dart';

import '../domain/search_repository.dart';

/// Top-level UI status for search results — the canonical 4-state machine
/// (40_GUARDRAILS_ARCH §2.1 / §3). `noResults` is NOT a fifth status: it is
/// `loaded` + an empty [SearchState.results].
enum SearchStatus {
  /// No query yet — the prompt / suggestions surface.
  idle,

  /// A query is on the wire.
  loading,

  /// A query landed (results may be empty → "no results").
  loaded,

  /// The query failed (network / unauthorized / unavailable).
  failed,
}

/// Immutable state for free-text search.
class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.results = const <SearchResult>[],
    this.error,
  });

  final SearchStatus status;

  /// The trimmed query that produced [results] / [error].
  final String query;

  final List<SearchResult> results;

  /// Typed failure from the last query.
  final SearchFailure? error;

  bool get hasResults => results.isNotEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<SearchResult>? results,
    SearchFailure? error,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, query, results, error];
}
