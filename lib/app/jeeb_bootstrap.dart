import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'app.dart';
import 'bootstrap.dart';
import 'branded_splash.dart';

/// Debug-only flag (`--dart-define=JEEB_HOLD_SPLASH=true`) that keeps the
/// branded splash on screen after bootstrap resolves, so the screen can be
/// captured deterministically on the emulator. It renders the *production*
/// [BrandedSplash] under the production theme + l10n — it never changes what
/// ships. No-op in release builds.
const bool _kHoldSplash =
    bool.fromEnvironment('JEEB_HOLD_SPLASH') && kDebugMode;

/// Debug-only locale override (`--dart-define=JEEB_FORCE_LOCALE=ar`) used to
/// capture the RTL splash deterministically on an emulator that can't have its
/// system locale changed without root. Honored only in debug builds; the
/// production locale resolution (device locale → prefs) is untouched.
///
/// Must be a `const String.fromEnvironment` so `--dart-define` injects at
/// compile time — wrapping it in a runtime ternary would discard the value.
const String _kForcedLocaleDefine = String.fromEnvironment('JEEB_FORCE_LOCALE');
const String _kForcedLocale = kDebugMode ? _kForcedLocaleDefine : '';

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
        if (snapshot.connectionState != ConnectionState.done || _kHoldSplash) {
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
    final candidate = _kForcedLocale.isNotEmpty
        ? _kForcedLocale
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
