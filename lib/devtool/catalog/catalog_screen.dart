import 'package:flutter/material.dart';

import '../../core/theme/jeeb_semantic_colors.dart';
import 'catalog_network_guard.dart';
import 'screen_catalog.dart';

class CatalogMenuScreen extends StatelessWidget {
  const CatalogMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = kScreenCatalog;
    final coveredFeatures = entries.map((e) => e.feature).toSet().length;
    return Scaffold(
      appBar: AppBar(title: const Text('Screen Catalog')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cataloged $coveredFeatures of $kTotalFeatureCount features '
                '· ${entries.length} screens',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final entry = entries[i];
                return ListTile(
                  title: Text(entry.screen),
                  subtitle: Text(
                    '${entry.feature} · ${entry.states.length} state'
                    '${entry.states.length == 1 ? '' : 's'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogStatesScreen(entry: entry),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogStatesScreen extends StatelessWidget {
  const CatalogStatesScreen({required this.entry, super.key});

  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.screen)),
      body: ListView.separated(
        itemCount: entry.states.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final state = entry.states[i];
          return ListTile(
            leading: const Icon(Icons.visibility),
            title: Text(state.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CatalogPreview(
                  title: '${entry.screen} · ${state.label}',
                  childBuilder: state.builder,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({required this.title, required this.childBuilder});

  final String title;
  final WidgetBuilder childBuilder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.midnight();
    return Stack(
      children: [
        Positioned.fill(child: CatalogNetworkGuard(builder: childBuilder)),
        PositionedDirectional(
          top: MediaQuery.of(context).padding.top + 4,
          start: 4,
          child: Material(
            // The escape hatch floats over a captured screen, so it takes the
            // kit's floating-circle recipe rather than a black scrim.
            color: semantics.glassFillPressed,
            shape: CircleBorder(
              side: BorderSide(color: semantics.glassBorderStrong),
            ),
            child: IconButton(
              icon: const Icon(Icons.close),
              color: scheme.onSurface,
              tooltip: 'Back to catalog',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}
