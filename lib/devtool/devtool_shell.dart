import 'package:flutter/material.dart';

import '../core/dev_flags.dart';

/// The six top-level sections of the Jeeber Dev Tool. Each maps to a feature
/// from the Dev Tool spec (see docs/devtool/DESIGN.md). DT-02+ wire real routes;
/// DT-01 ships the runnable scaffold so both APKs build and install.
enum DevToolSection {
  superLogin('Super Login', 'Log in as any user (moved out of the app)', Icons.login),
  screenCatalog('Screen Catalog', 'Every screen + its mocked UI states', Icons.grid_view),
  actions('Actions', 'Pick a user → initiate offer, message, accept…', Icons.bolt),
  serverUrl('Server URL', 'Point the app at a different backend', Icons.dns),
  clearData('Clear Local Data', 'Factory-reset this device', Icons.delete_sweep),
  users('Scenario Users', 'Create users in a specific scenario', Icons.person_add);

  const DevToolSection(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Root widget for the Jeeber Dev Tool app (`main_devtool.dart` entrypoint).
class DevToolApp extends StatelessWidget {
  const DevToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeeber Dev Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C3DF4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DevToolShell(),
    );
  }
}

/// Home menu listing the six Dev Tool sections.
class DevToolShell extends StatelessWidget {
  const DevToolShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Defensive: this shell must only ever run inside the Dev Tool distribution.
    assertDevToolOnly('DevToolShell');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeeber Dev Tool'),
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: DevToolSection.values.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final section = DevToolSection.values[i];
          return ListTile(
            leading: Icon(section.icon),
            title: Text(section.title),
            subtitle: Text(section.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DevToolSectionPage(section: section),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Placeholder destination for a Dev Tool section. Each real section
/// (super-login DT-03, catalog DT-04, actions DT-06, users DT-07, settings
/// DT-08) replaces the [placeholder] body with its screen; the routing +
/// AppBar chrome is owned here so those tickets only supply content.
class DevToolSectionPage extends StatelessWidget {
  const DevToolSectionPage({required this.section, super.key});

  final DevToolSection section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.icon, size: 48),
              const SizedBox(height: 16),
              Text(section.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Implementation pending (${section.name})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
