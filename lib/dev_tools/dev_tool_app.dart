import 'package:flutter/material.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';

import 'ui/tools_menu_screen.dart';

/// Root of the "Jeeb Dev Tool" testing app.
///
/// A plain [MaterialApp] whose home is the [ToolsMenuScreen] (the tool's own
/// navigation stack: menu → screen catalog → states → preview). Each preview
/// spins up its OWN `MaterialApp.router` internally (see `preview_host.dart`),
/// so this outer shell only owns the tool's chrome and navigation.
///
/// The tool reuses the real [AppTheme] so it feels native, but it is entirely
/// independent of the product app — no router, no Firebase, no DI.
class DevToolApp extends StatelessWidget {
  const DevToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeeb Dev Tool',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const ToolsMenuScreen(),
    );
  }
}
