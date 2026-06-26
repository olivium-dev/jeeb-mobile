// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer
// rules) — the application + data layers depend on this contract, never the
// reverse.
//
// Sprint-5 Stream C search domain contract. The mobile gateway does not expose
// a public free-text search BFF endpoint yet (only the CMS-admin `?q=` filters
// exist), so the DI default is the [DioSearchRepository] guarded by a graceful
// `SearchFailure.unavailable` fall-back: when the `/v1/search` route is absent
// the screen renders an honest "search isn't available yet" empty state rather
// than a dead-end or a fabricated result list.

/// The typed kind of a search hit. Each kind dispatches to a different route on
/// tap (the [SearchResultsScreen] row handler). `unknown` never navigates
/// (AP-9 honesty — never fabricate a destination the row can't address).
enum SearchResultKind {
  /// An order / active delivery → `/orders/:id` (`delivery-detail`).
  order,

  /// A conversation thread → `/chat/:id` (`chat-detail`).
  conversation,

  /// A hit whose target route can't be addressed from the payload.
  unknown,
}

/// A single search hit (`search_result_<id>`). `kind` + `refId` together
/// address the deep-link target; `title`/`subtitle` are the display payload.
class SearchResult {
  const SearchResult({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.refId,
  });

  final String id;
  final SearchResultKind kind;
  final String title;
  final String? subtitle;

  /// The deep-link target id (order / conversation). Defaults to [id] when the
  /// payload omits a distinct reference.
  final String? refId;
}

/// Typed failure surfaced from a search action — never a raw exception or
/// string (40_GUARDRAILS_ARCH §2.1).
enum SearchFailure {
  /// Transport error (offline / timeout) — retryable.
  network,

  /// 401 / 403 — the session expired.
  unauthorized,

  /// The search endpoint does not exist (404) — surfaced as an honest
  /// "not available" empty state, NOT a hard error.
  unavailable,

  /// Anything else.
  unknown,
}

class SearchRepositoryException implements Exception {
  const SearchRepositoryException(this.failure, [this.message]);

  final SearchFailure failure;
  final String? message;

  @override
  String toString() => 'SearchRepositoryException($failure, $message)';
}

/// Domain contract for free-text search.
abstract class SearchRepository {
  /// Run a free-text [query]. The query is pre-trimmed and guaranteed
  /// non-empty by the caller (the cubit). Throws [SearchRepositoryException]
  /// on failure.
  Future<List<SearchResult>> search(String query);
}
