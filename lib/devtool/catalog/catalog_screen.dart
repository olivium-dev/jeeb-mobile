import 'package:flutter/material.dart';

import 'catalog_menu_view.dart';
import 'catalog_network_guard.dart';
import 'screen_catalog.dart';

/// DT-04 / F2 — Screen Catalog menu. Lists every cataloged screen (searchable);
/// tapping one drills into its mocked UI states, and tapping a state previews
/// the real screen (locally mocked, no network) so designers can review without
/// navigating the live app.
class CatalogMenuScreen extends StatelessWidget {
  const CatalogMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogMenuView(
      entries: kScreenCatalog,
      onOpen: (entry) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CatalogStatesScreen(entry: entry),
        ),
      ),
    );
  }
}

/// The list of mocked states for one cataloged screen.
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

/// Hosts a previewed screen with a thin overlay bar so the reviewer can always
/// get back (the previewed screen owns its own Scaffold/AppBar).
class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({required this.title, required this.childBuilder});

  final String title;
  final WidgetBuilder childBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CatalogNetworkGuard(builder: childBuilder)),
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          left: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Back to catalog',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}
