import '../domain/search_repository.dart';

/// Inert [SearchRepository] used when GetIt is not configured (router-resolution
/// widget tests) — signals the honest "search isn't available" state rather
/// than returning a fabricated empty result set that reads as "no matches".
class EmptySearchRepository implements SearchRepository {
  const EmptySearchRepository();

  @override
  Future<List<SearchResult>> search(String query) async {
    throw const SearchRepositoryException(SearchFailure.unavailable);
  }
}
