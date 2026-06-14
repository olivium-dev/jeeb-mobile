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

/// Minimum wall-clock time the branded splash stays on screen so a first-time
/// user actually *sees* the Jeeb logo (FR-D1D2 / D1).
///
/// [Bootstrap.minimal] targets < 250 ms, so without a floor the branded splash
/// flashes for a single frame and is gone before the eye (or a post-launch
/// screenshot) registers it — Codex QA could not confirm the logo was ever
/// shown. This hold is a *floor on display time*, NOT extra init work: bootstrap
/// runs concurrently with the timer, so cold start is not slowed — we only wait
/// out the remaining slice of the floor if bootstrap finished first. ~1.3 s sits
/// in the 1.2–1.5 s perceptible-brand band the requirement asks for.
const Duration _kMinSplashHold = Duration(milliseconds: 1300);

/// Cold-start host (T-mobile-047; min-splash-hold added in FR-D1D2).
///
/// Runs [Bootstrap.minimal] while the branded splash paints, swaps in
/// [JeebApp] once BOTH bootstrap has resolved AND the [_kMinSplashHold] floor
/// has elapsed, then triggers [Bootstrap.deferred] from a post-first-frame
/// callback so non-critical work never blocks first paint.
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

  /// Test seam — lets widget tests collapse the splash floor to [Duration.zero]
  /// (or drive it deterministically with `tester.pump`) instead of waiting out
  /// the real ~1.3 s. Production leaves it null and uses [_kMinSplashHold].
  final Duration? _minSplashHold;

  @override
  State<JeebBootstrap> createState() => _JeebBootstrapState();
}

class _JeebBootstrapState extends State<JeebBootstrap> {
  late final Future<BootstrapResult> _bootstrap =
      widget._override ?? Bootstrap.minimal();

  /// Flips true when the minimum-display floor has elapsed. The app is only
  /// shown once this AND bootstrap completion are both satisfied.
  bool _minHoldElapsed = false;
  Timer? _holdTimer;

  bool _deferredScheduled = false;

  @override
  void initState() {
    super.initState();
    // Start the floor timer concurrently with bootstrap (which began in the
    // field initializer above). A zero-duration hold completes on the next
    // microtask, so tests opting out never wait a real frame budget.
    final hold = widget._minSplashHold ?? _kMinSplashHold;
    if (hold <= Duration.zero) {
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
        // An error must surface immediately — never trap a broken boot behind
        // the cosmetic splash floor.
        if (snapshot.hasError) {
          // Bootstrap failure is unrecoverable (SharedPreferences platform
          // channel is broken). Surface it so it isn't silently swallowed.
          return _BootstrapErrorApp(error: snapshot.error!);
        }
        final bootstrapping =
            snapshot.connectionState != ConnectionState.done;
        // Hold the branded splash until bootstrap is done AND the user has had
        // a perceptible look at the logo (or the debug hold-splash seam pins it).
        if (bootstrapping || !_minHoldElapsed || _holdSplash) {
          return const _SplashApp();
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
