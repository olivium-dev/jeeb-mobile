import 'package:flutter/material.dart';

import '../catalog/dev_screen_catalog.dart';
import '../catalog/dev_screen_entry.dart';
import 'screen_states_screen.dart';

/// The interactive Screen Catalog: search + group filter over [devScreenCatalog],
/// rendered grouped by `group` with section headers (entries sorted alphabetically
/// within each group). Tapping an entry opens its [ScreenStatesScreen].
class ScreenCatalogScreen extends StatefulWidget {
  const ScreenCatalogScreen({super.key});

  @override
  State<ScreenCatalogScreen> createState() => _ScreenCatalogScreenState();
}

/// Sentinel group-filter value meaning "no group filter".
const String _allGroups = 'All';

class _ScreenCatalogScreenState extends State<ScreenCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _group = _allGroups;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Distinct groups present in the catalog, sorted, with 'All' first.
  List<String> get _groupOptions {
    final groups = devScreenCatalog.map((e) => e.group).toSet().toList()..sort();
    return <String>[_allGroups, ...groups];
  }

  bool _matchesQuery(DevScreenEntry entry) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    if (entry.title.toLowerCase().contains(q)) return true;
    if (entry.id.toLowerCase().contains(q)) return true;
    return entry.keywords.any((k) => k.toLowerCase().contains(q));
  }

  List<DevScreenEntry> get _filtered {
    return devScreenCatalog
        .where((e) => _group == _allGroups || e.group == _group)
        .where(_matchesQuery)
        .toList();
  }

  /// Filtered entries grouped by `group`; groups sorted alphabetically, entries
  /// sorted alphabetically by title within each group.
  List<MapEntry<String, List<DevScreenEntry>>> get _grouped {
    final byGroup = <String, List<DevScreenEntry>>{};
    for (final entry in _filtered) {
      byGroup.putIfAbsent(entry.group, () => <DevScreenEntry>[]).add(entry);
    }
    final groupNames = byGroup.keys.toList()..sort();
    return <MapEntry<String, List<DevScreenEntry>>>[
      for (final name in groupNames)
        MapEntry(
          name,
          byGroup[name]!..sort((a, b) => a.title.compareTo(b.title)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final grouped = _grouped;

    return Scaffold(
      appBar: AppBar(title: const Text('Screens')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by title, id or keyword',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _groupOptions.contains(_group) ? _group : _allGroups,
                    items: <DropdownMenuItem<String>>[
                      for (final option in _groupOptions)
                        DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _group = value ?? _allGroups),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${filtered.length} '
                '${filtered.length == 1 ? 'screen' : 'screens'}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No screens match "$_query"',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView(
                    children: <Widget>[
                      for (final group in grouped) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            group.key,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final entry in group.value)
                          ListTile(
                            title: Text(entry.title),
                            subtitle: Text(
                              '${entry.id} · '
                              '${entry.states.length} '
                              '${entry.states.length == 1 ? 'state' : 'states'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ScreenStatesScreen(entry: entry),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
