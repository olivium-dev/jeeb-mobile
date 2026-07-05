import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../catalog/dev_screen_entry.dart';
import 'preview_host.dart';

/// Hosts a single [DevScreenState] as a LIVE, interactive preview.
///
/// The previewed screen runs inside its own `MaterialApp.router` (see
/// [devPreviewHost]) with a stable [GoRouter] created ONCE per preview and held
/// in this State — never rebuilt on a toggle, so the screen's cubit/router state
/// survives the light/dark and locale toggles.
///
/// The tool's own AppBar (owned by the outer Navigator) shows
/// `<title> / <state.label>` plus a light/dark toggle and an EN/AR locale toggle
/// that overrides the state's default locale.
class ScreenPreviewScreen extends StatefulWidget {
  const ScreenPreviewScreen({
    super.key,
    required this.entry,
    required this.state,
  });

  final DevScreenEntry entry;
  final DevScreenState state;

  @override
  State<ScreenPreviewScreen> createState() => _ScreenPreviewScreenState();
}

class _ScreenPreviewScreenState extends State<ScreenPreviewScreen> {
  // Built ONCE, on the first build, using this State's context. The screen (and
  // its cubit / fakes) is created a single time and reused across toggles.
  late final Widget _child = widget.state.builder(context);

  // The GoRouter is created ONCE and reused — a rebuild would drop the screen's
  // navigation + cubit state.
  late final GoRouter _router = buildDevPreviewRouter(_child);

  late bool _dark = _initialDark();
  late Locale _locale = widget.state.locale;

  bool _initialDark() {
    // Default to the state's implied brightness at open time — follow the
    // platform so the preview opens matching the device, then let the user
    // toggle. (Kept simple: start light unless the platform is dark.)
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return platformBrightness == Brightness.dark;
  }

  bool get _isArabic => _locale.languageCode == 'ar';

  void _toggleDark() => setState(() => _dark = !_dark);

  void _toggleLocale() => setState(() {
        _locale = _isArabic ? const Locale('en') : const Locale('ar');
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.entry.title} / ${widget.state.label}'),
        actions: <Widget>[
          IconButton(
            tooltip: _isArabic ? 'Switch to English' : 'Switch to Arabic',
            onPressed: _toggleLocale,
            icon: Text(
              _isArabic ? 'AR' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: _dark ? 'Switch to light' : 'Switch to dark',
            onPressed: _toggleDark,
            icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: devPreviewHost(
        router: _router,
        locale: _locale,
        dark: _dark,
      ),
    );
  }
}
