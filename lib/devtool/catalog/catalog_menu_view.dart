import 'package:flutter/material.dart';

import 'catalog_models.dart';
import 'catalog_search.dart';

/// The Screen Catalog list and its search box, kept independent of *which*
/// catalog it renders: `CatalogMenuScreen` hands it `kScreenCatalog`, while
/// tests can hand it a handful of entries and so exercise the search without
/// compiling every cataloged feature screen.
class CatalogMenuView extends StatefulWidget {
  const CatalogMenuView({
    required this.entries,
    required this.onOpen,
    super.key,
    this.totalFeatureCount = kTotalFeatureCount,
  });

  final List<CatalogEntry> entries;
  final ValueChanged<CatalogEntry> onOpen;
  final int totalFeatureCount;

  @override
  State<CatalogMenuView> createState() => _CatalogMenuViewState();
}

class _CatalogMenuViewState extends State<CatalogMenuView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clear() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.entries;
    final terms = catalogSearchTerms(_query);
    final matches = filterCatalog(all, _query);
    final coveredFeatures = all.map((e) => e.feature).toSet().length;
    final searching = terms.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Screen Catalog')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: 'Search screens — e.g. "delivery active"',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: _clear,
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                searching
                    ? '${matches.length} of ${all.length} screens match'
                    : 'Cataloged $coveredFeatures of ${widget.totalFeatureCount}'
                          ' features · ${all.length} screens',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No screen matches "$_query".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = matches[i];
                      final viaStates = catalogMatchExplanation(entry, terms);
                      return ListTile(
                        title: Text(entry.screen),
                        isThreeLine: viaStates.isNotEmpty,
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.feature} · ${entry.states.length} state'
                              '${entry.states.length == 1 ? '' : 's'}',
                            ),
                            // Say why a row without the words in its own name
                            // is here, so it does not read as a stray hit.
                            if (viaStates.isNotEmpty)
                              Text(
                                'matched state: ${viaStates.join(' · ')}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => widget.onOpen(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
