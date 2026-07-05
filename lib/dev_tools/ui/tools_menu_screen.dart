import 'package:flutter/material.dart';

import 'screen_catalog_screen.dart';

/// Landing screen of the dev tool — a list of available testing tools.
///
/// For the FOUNDATION there is exactly ONE tool ("Screens"). It is deliberately
/// structured as a list so more tools (network inspector, seam harness, feature
/// flags, …) can be appended later without reshaping the UI.
class ToolsMenuScreen extends StatelessWidget {
  const ToolsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeeb Dev Tool')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: const Text('Screens'),
            subtitle: const Text('Preview every screen with mock data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ScreenCatalogScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
