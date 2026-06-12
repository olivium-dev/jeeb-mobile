import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/dev_seam/dev_seam.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'app.dart';
import 'bootstrap.dart';
import 'branded_splash.dart';

/// Debug-only flag that keeps the branded splash on screen after bootstrap
/// resolves, resolved at RUNTIME from [DevSeam] (replaces the compile-time
/// `JEEB_HOLD_SPLASH`; the dart-define still feeds it via the seam fallback).
/// Renders the *production* [BrandedSplash] under the production theme + l10n —
/// it never changes what ships. No-op in release builds.
bool get _holdSplash => kDebugMode && DevSeam.current.holdSplash;

/// Debug-only locale override, resolved at RUNTIME from [DevSeam] (replaces the
/// compile-time `JEEB_FORCE_LOCALE`). Used to capture the RTL splash on an
/// emulator that can't change its system locale without root. Honored only in
/// debug builds; the production locale resolution is untouched.
String get _forcedLocale => kDebugMode ? DevSeam.current.forcedLocale : '';

/// Cold-start host (T-mobile-047).
///
/// Runs [Bootstrap.minimal] while the branded splash paints, swaps in
/// [JeebApp] when ready, then triggers [Bootstrap.deferred] from a
/// post-first-frame callback so non-critical work never blocks first paint.
///
/// Splitting the bootstrap into two phases (instead of `await`ing everything
/// in `main()`) is the single biggest cold-start win: the user sees branded
/// pixels in one frame instead of waiting for `initializeDateFormatting()` to
/// page in every locale.
class JeebBootstrap extends StatefulWidget {
  const JeebBootstrap({super.key, Future<BootstrapResult>? bootstrapFuture})
      : _override = bootstrapFuture;

  /// Test seam — lets unit tests supply a pre-resolved [BootstrapResult]
  /// instead of touching the real [SharedPreferences] platform channel.
  final Future<BootstrapResult>? _override;

  @override
  State<JeebBootstrap> createState() => _JeebBootstrapState();
}

class _JeebBootstrapState extends State<JeebBootstrap> {
  late final Future<BootstrapResult> _bootstrap =
      widget._override ?? Bootstrap.minimal();

  bool _deferredScheduled = false;

  void _scheduleDeferred() {
    if (_deferredScheduled) return;
    _deferredScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Fire-and-forget — failures here must not crash the app since this
      // is, by definition, non-critical init.
      Bootstrap.deferred();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _holdSplash) {
          return const _SplashApp();
        }
        if (snapshot.hasError) {
          // Bootstrap failure is unrecoverable (SharedPreferences platform
          // channel is broken). Surface it so it isn't silently swallowed.
          return _BootstrapErrorApp(error: snapshot.error!);
        }
        _scheduleDeferred();
        final result = snapshot.requireData;
        return JeebApp(
          preferences: result.preferences,
          crashReporter: result.crashReporter,
        );
      },
    );
  }
}

/// Pre-bootstrap host for [BrandedSplash]. Wires the production OMDS theme and
/// the [AppLocalizations] delegates so the splash consumes `colorScheme` roles
/// and ARB strings — never literals. Locale resolves from the device locale
/// (constrained to supported locales) so an Arabic device renders the splash
/// mirrored from the very first frame, before prefs are loaded.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  static Locale _initialLocale() {
    final forced = _forcedLocale;
    final candidate = forced.isNotEmpty
        ? forced
        : PlatformDispatcher.instance.locale.languageCode;
    final supported =
        AppLocalizations.supportedLocales.any((l) => l.languageCode == candidate);
    return supported ? Locale(candidate) : const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: _initialLocale(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const BrandedSplash(),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'App failed to start: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
