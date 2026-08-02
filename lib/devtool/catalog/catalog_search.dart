import 'catalog_models.dart';

/// Query separators. A space means AND — "Delivery Active" is two terms that
/// both have to appear — and the punctuation that shows up inside catalog names
/// (`Location Picker (pickup/dropoff)`, `feature_name`) separates terms too, so
/// a copy-pasted name still searches sensibly. Unicode letters survive the
/// split, so an Arabic query stays one term instead of being erased.
final RegExp _termSeparators = RegExp(r'[\s/_\-·,()]+');

/// Splits a raw query into lowercased search terms.
List<String> catalogSearchTerms(String query) => query
    .toLowerCase()
    .split(_termSeparators)
    .where((term) => term.isNotEmpty)
    .toList(growable: false);

/// Everything one entry can be found by: its screen name, its feature, and the
/// labels of its mocked states (so "empty" or "error" finds the screens that
/// have one).
String catalogHaystack(CatalogEntry entry) => <String>[
  entry.screen,
  entry.feature,
  ...entry.states.map((state) => state.label),
].join(' ').toLowerCase();

/// Loose match: case-insensitive, order-independent, and substring-based rather
/// than word-based, so "delivery active" finds `ActiveDeliveryJeeberScreen`.
/// Every term must hit — an empty query matches everything.
bool catalogEntryMatches(CatalogEntry entry, List<String> terms) {
  if (terms.isEmpty) return true;
  final haystack = catalogHaystack(entry);
  return terms.every((term) => haystack.contains(term));
}

/// Why an entry matched when its own name does not say so: the state labels
/// carrying the terms the screen and feature names leave unaccounted for.
///
/// Searching "delivery active" turns up JeeberRequestDetailLoader, whose only
/// claim to either word is a state called "Unavailable — feed miss, no active
/// delivery either". Without surfacing that label the row looks like a bug, so
/// the menu prints it under the row. Empty when the name and feature already
/// explain the hit.
List<String> catalogMatchExplanation(CatalogEntry entry, List<String> terms) {
  if (terms.isEmpty) return const <String>[];
  final named = '${entry.screen} ${entry.feature}'.toLowerCase();
  final unexplained = terms.where((term) => !named.contains(term));
  if (unexplained.isEmpty) return const <String>[];
  return entry.states
      .where((state) {
        final label = state.label.toLowerCase();
        return unexplained.any(label.contains);
      })
      .map((state) => state.label)
      .toList(growable: false);
}

/// Filters [entries] by [query], preserving the catalog's feature ordering.
List<CatalogEntry> filterCatalog(List<CatalogEntry> entries, String query) {
  final terms = catalogSearchTerms(query);
  if (terms.isEmpty) return entries;
  return entries
      .where((entry) => catalogEntryMatches(entry, terms))
      .toList(growable: false);
}
