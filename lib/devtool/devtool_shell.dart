import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:omds/omds.dart';

import '../app/bootstrap.dart';
import '../core/dev_flags.dart';
import '../core/di/injection_container.dart';
import '../core/diagnostics/gesture_log.dart';
import '../core/observability/session_trace/observability_config.dart';
import '../core/observability/session_trace/presentation/obs_overlay.dart';
import '../core/theme/app_theme.dart';
import '../features/registration/data/super_login_demo_user.dart';
import '../features/registration/data/super_login_service.dart';
import 'actions/actions_page.dart';
import 'catalog/catalog_screen.dart';
import 'dev_settings_page.dart';
import 'location_simulation/location_simulator_page.dart';
import 'users/scenario_users_page.dart';
import '../features/registration/presentation/super_login/super_login_sheet.dart';
import 'super_login/full_roster_login.dart';
import '../l10n/app_localizations.dart';

enum DevToolSection {
  superLogin(
    'Super Login',
    'Log in as any user (moved out of the app)',
    Icons.login,
  ),
  screenCatalog(
    'Screen Catalog',
    'Every screen + its mocked UI states',
    Icons.grid_view,
  ),
  actions(
    'Actions',
    'Pick a user → initiate offer, message, accept…',
    Icons.bolt,
  ),
  locationSimulator(
    'Location Simulator',
    'Move an assigned Jeeber through a delivery route',
    Icons.route,
  ),
  serverUrl('Server URL', 'Point the app at a different backend', Icons.dns),
  clearData(
    'Clear Local Data',
    'Factory-reset this device',
    Icons.delete_sweep,
  ),
  users(
    'Scenario Users',
    'Create users in a specific scenario',
    Icons.person_add,
  );

  const DevToolSection(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Registers the services [SuperLoginPage] resolves out of [sl].
///
/// This is the ONLY registration site for [SuperLoginService] and
/// [SuperLoginDemoUserService] in the app, and product DI does not perform it —
/// so every path that can reach [DevToolShell] must call this first, or
/// `super_login_sheet.dart`'s `sl<SuperLoginService>()` throws in GetIt. There
/// are two such paths: [DevToolApp] (the Android launcher icon) and the iOS
/// shake layer in `shake/devtool_shake.dart`. Idempotent by construction, so a
/// second call from either path is harmless.
void registerDevToolSuperLoginDependencies() {
  if (!sl.isRegistered<SuperLoginService>()) {
    sl.registerLazySingleton<SuperLoginService>(
      () => DefaultSuperLoginService(dio: sl()),
    );
  }
  if (!sl.isRegistered<SuperLoginDemoUserService>()) {
    sl.registerLazySingleton<SuperLoginDemoUserService>(
      () => DefaultSuperLoginDemoUserService(dio: sl()),
    );
  }
}

/// Root widget for the Jeeber Dev Tool (`/devtool` route via the `.DevToolLauncher`
/// launcher icon). It runs the SAME [Bootstrap.minimal] the real app runs, so the
class DevToolApp extends StatefulWidget {
  const DevToolApp({super.key});

  @override
  State<DevToolApp> createState() => _DevToolAppState();
}

class _DevToolAppState extends State<DevToolApp> {
  late final Future<BootstrapResult> _bootstrap = _bootstrapDevTool();

  Future<BootstrapResult> _bootstrapDevTool() async {
    final result = await Bootstrap.minimal();
    registerDevToolSuperLoginDependencies();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeeber Dev Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Session-trace observability tool (devtool-only): mounts the SAME
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return kObsCompiledIn ? ObsOverlayHost(child: content) : content;
      },
      home: FutureBuilder<BootstrapResult>(
        future: _bootstrap,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _DevToolErrorScreen(error: snapshot.error!);
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const DevToolShell();
        },
      ),
    );
  }
}

class DevToolShell extends StatelessWidget {
  const DevToolShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Defensive: this shell must only ever run inside a dev-tool-enabled build.
    assertDevToolOnly('DevToolShell');
    return Scaffold(
      appBar: AppBar(title: const Text('Jeeber Dev Tool'), centerTitle: false),
      body: Column(
        children: [
          const _GestureLoggingSwitch(),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
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
                  onTap: () => _openSection(context, section),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openSection(BuildContext context, DevToolSection section) {
    switch (section) {
      case DevToolSection.superLogin:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SuperLoginPage()));
      case DevToolSection.serverUrl:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ServerUrlPage()));
      case DevToolSection.clearData:
        showClearLocalDataDialog(context);
      case DevToolSection.screenCatalog:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CatalogMenuScreen()),
        );
      case DevToolSection.actions:
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ActionsPage()));
      case DevToolSection.locationSimulator:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const LocationSimulatorPage(),
          ),
        );
      case DevToolSection.users:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ScenarioUsersPage()),
        );
    }
  }
}

class _GestureLoggingSwitch extends StatelessWidget {
  const _GestureLoggingSwitch();

  @override
  Widget build(BuildContext context) {
    final gestureLog = GestureLog.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: gestureLog.enabledListenable,
      builder: (context, enabled, _) => OmdsSwitchTile(
        key: const ValueKey('devtool.gestureLoggingSwitch'),
        leading: const Icon(Icons.touch_app),
        title: 'Gesture Logging',
        subtitle: enabled ? 'On — taps logged to diag stream' : 'Off',
        value: enabled,
        onChanged: (value) => gestureLog.enabled = value,
      ),
    );
  }
}

class SuperLoginPage extends StatelessWidget {
  const SuperLoginPage({super.key});

  Future<void> _superLogin(BuildContext context) async {
    final signedIn = await showSuperLoginSheet(context);
    if (!context.mounted) return;
    _reportResult(context, signedIn);
  }

  void _superLoginPlus(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FullRosterLoginPage()),
    );
  }

  void _reportResult(BuildContext context, bool? signedIn) {
    if (signedIn != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed in — the Jeeb app now shares this session.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Login')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Super Login'),
            subtitle: const Text('Enter a user id + passcode'),
            onTap: () => _superLogin(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.people_alt),
            title: const Text('Super Login Plus'),
            subtitle: const Text(
              'Pick from ALL live users (search) — instant login',
            ),
            onTap: () => _superLoginPlus(context),
          ),
        ],
      ),
    );
  }
}

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

class _DevToolErrorScreen extends StatelessWidget {
  const _DevToolErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Dev Tool failed to start: $error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
