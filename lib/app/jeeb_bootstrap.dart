import 'dart:async';
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

// JM-006 (D79/D85): the branded splash has NO artificial display dwell.
//
// History — an earlier change (FR-D1D2 / D1) added a fixed ~1.3 s floor on the
// splash so a first-time user (and a post-launch QA screenshot) could register
// the Jeeb logo. `20_GAP_MAP.md §splash` flags that exact "cosmetic 1.3 s host"
// as the JM-006 gap, and `22_DESIGN_NOTES.md` fixes the splash contract as
// "auto-route by session … no UI dwell". JM-006 is the later, more specific
// ruling and supersedes the cosmetic floor: the splash is a passive boot frame
// that must hand off to [JeebApp] — and therefore to the session-aware
// `_firstRunRedirect` in `app_router.dart` — the instant [Bootstrap.minimal]
// resolves, so the redirect is never delayed by a fabricated timer.
//
// Production therefore uses NO hold (`minSplashHold == null` → no floor). A
// non-zero [JeebBootstrap.minSplashHold] is honored only as a debug/test opt-in
// (deterministic widget-test pumping); the debug-only `holdSplash` dev seam
// still pins the splash for screenshot-evidence flows. Neither path ships a
// default dwell, so the production splash never fights the redirect (D79/D85).

/// Cold-start host (T-mobile-047; JM-006 removed the FR-D1D2 splash floor).
///
/// Runs [Bootstrap.minimal] while the branded splash paints and swaps in
/// [JeebApp] the moment bootstrap resolves — with no artificial floor in front
/// of the router's session-aware redirect (JM-006, D79/D85). It then triggers
/// [Bootstrap.deferred] from a post-first-frame callback so non-critical work
/// never blocks first paint.
///
/// Splitting the bootstrap into two phases (instead of `await`ing everything
/// in `main()`) is the single biggest cold-start win: the user sees branded
/// pixels in one frame instead of waiting for `initializeDateFormatting()` to
/// page in every locale.
class JeebBootstrap extends StatefulWidget {
  const JeebBootstrap({
    super.key,
    Future<BootstrapResult>? bootstrapFuture,
    Duration? minSplashHold,
  })  : _override = bootstrapFuture,
        _minSplashHold = minSplashHold;

  /// Test seam — lets unit tests supply a pre-resolved [BootstrapResult]
  /// instead of touching the real [SharedPreferences] platform channel.
  final Future<BootstrapResult>? _override;

  /// Debug/test-only opt-in hold. Production passes `null` (and `main.dart`
  /// constructs `const JeebBootstrap()`), so there is **no** display floor and
  /// the splash hands straight off to the router once bootstrap resolves
  /// (JM-006, D79/D85). A non-null value lets a widget test pin the splash for a
  /// deterministic number of `tester.pump` frames; [Duration.zero] (or null)
  /// means "swap as soon as bootstrap is done". Never set in release.
  final Duration? _minSplashHold;

  @override
  State<JeebBootstrap> createState() => _JeebBootstrapState();
}

class _JeebBootstrapState extends State<JeebBootstrap> {
  late final Future<BootstrapResult> _bootstrap =
      widget._override ?? Bootstrap.minimal();

  /// Flips true once any opt-in [JeebBootstrap._minSplashHold] has elapsed.
  /// Production sets no hold, so this is `true` from the first frame and the
  /// app shows the instant bootstrap completes — the only thing the splash ever
  /// waits on is real init, never a fabricated floor (JM-006, D79/D85).
  bool _minHoldElapsed = false;
  Timer? _holdTimer;

  bool _deferredScheduled = false;

  @override
  void initState() {
    super.initState();
    // JM-006 (D79/D85): no production dwell. The hold is null in production, so
    // _minHoldElapsed is already satisfied and the splash hands off to the
    // router (and _firstRunRedirect) as soon as Bootstrap.minimal() resolves.
    // A non-zero hold is a debug/test opt-in only; it runs concurrently with
    // bootstrap so it never adds latency on top of real init.
    final hold = widget._minSplashHold;
    if (hold == null || hold <= Duration.zero) {
      _minHoldElapsed = true;
    } else {
      _holdTimer = Timer(hold, () {
        if (!mounted) return;
        setState(() => _minHoldElapsed = true);
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _scheduleDeferred(BootstrapResult result) {
    if (_deferredScheduled) return;
    _deferredScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Fire-and-forget — failures here must not crash the app since this is,
      // by definition, non-critical init. Pass the bootstrap crash reporter so
      // the deferred phase can upgrade its delegate from Noop to Crashlytics
      // once the (off-critical-path, timeboxed) Firebase init resolves — the
      // cold-start ANR fix keeps that native call out of [Bootstrap.minimal].
      Bootstrap.deferred(crashReporter: result.crashReporter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        // An error must surface immediately — never trap a broken boot behind
        // the splash.
        if (snapshot.hasError) {
          // Bootstrap failure is unrecoverable (SharedPreferences platform
          // channel is broken). Surface it so it isn't silently swallowed.
          return _BootstrapErrorApp(error: snapshot.error!);
        }
        final bootstrapping =
            snapshot.connectionState != ConnectionState.done;
        // Show the branded splash ONLY while real init is in flight (JM-006,
        // D79/D85: no artificial dwell). In production _minHoldElapsed is true
        // from frame one, so the splash hands off to the router the instant
        // bootstrap resolves and _firstRunRedirect fires with no delay. The
        // !_minHoldElapsed term covers the debug/test opt-in hold; _holdSplash
        // is the debug-only screenshot-evidence seam.
        if (bootstrapping || !_minHoldElapsed || _holdSplash) {
          return const _SplashApp();
        }
        final result = snapshot.requireData;
        _scheduleDeferred(result);
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
