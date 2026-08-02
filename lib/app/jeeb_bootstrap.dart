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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:flutter/services.dart';
import '../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/app/jeeb_bootstrap_preview_test.dart
// ===========================================================================
//
// Widget previews for [JeebBootstrap] — run with
// `flutter widget-preview start`.
//
// [JeebBootstrap] is the cold-start host. It paints the branded splash while
// [Bootstrap.minimal] is in flight, an error host if that future rejects, and
// swaps in the real app the instant it resolves (JM-006/D79/D85 — no
// artificial dwell). Two of those three states are previewable, and the third
// is deliberately left out:
//
// * The **ready** state is NOT previewed. Reaching it needs a genuine
//   [BootstrapResult], whose `preferences` is a live `SharedPreferences`
//   instance that no fake can stand in for, and mounting it runs
//   `_scheduleDeferred` from a post-frame callback — that is
//   [Bootstrap.deferred], i.e. `Firebase.initializeApp()` plus
//   `initializeDateFormatting()`, fired from the preview canvas. The widget
//   exposes no seam to suppress that call, so a "ready" preview would break
//   the no-network rule in `lib/core/previews/README.md` rather than illustrate
//   anything. The splash→app hand-off is a *timing* contract and is already
//   pinned by `test/app/jeeb_bootstrap_test.dart`.
// * The **hold** state (`minSplashHold`) paints exactly the same pixels as the
//   bootstrapping state — same reason, same test.
//
// So what is left is what those tests never look at: the two hosts this widget
// builds itself. The error host in particular has no test anywhere in the repo
// and is the only screen in the app built from a bare [MaterialApp] — no
// `AppTheme`, no `AppLocalizations`, no locale, no retry. Four of the five
// previews are error payloads for that reason, chosen to span the shape of
// what a real boot failure puts in that string: opaque, typical, verbose, and
// non-Latin.
//
// Network-free by construction, not merely by the guard in `jeebPreviewHost`:
// every preview injects its own `bootstrapFuture`, so [Bootstrap.minimal]
// never runs, and no preview here ever reaches the branch that would schedule
// [Bootstrap.deferred].

/// This widget owns the whole viewport, so the canvas box is a phone, not a
/// component slot: 390×844 is the iPhone 14 / Galaxy S22 logical frame the
/// screen goldens use.
///
/// Public because the render test measures the error message against this exact
/// box — an overflow finding is only meaningful at the size the reviewer sees.
const Size jeebBootstrapPreviewBox = Size(390, 844);

/// A bootstrap future that never completes — the honest model of "init is still
/// running", and the only way to hold the splash on screen indefinitely without
/// a timer (a pending `Timer` would leak into the render tests).
Widget _jeebBootstrapBootstrapping() =>
    JeebBootstrap(bootstrapFuture: Completer<BootstrapResult>().future);

/// A bootstrap future that rejects with [error], which routes straight to the
/// error host: `FutureBuilder` reports `hasError` before it reports `done`, so
/// the splash is skipped entirely and this is the *first* thing a user with a
/// broken boot ever sees.
///
/// The future is already rejected by the time the root widget is built (the
/// microtask that delivers the error runs before the first frame), so without
/// [Future.ignore] the zone reports it as an UNHANDLED async error — a red
/// console in the canvas and a failed render test, neither of which is about
/// this widget. `ignore()` suppresses only that report: the `FutureBuilder`
/// still receives the error when it subscribes, which is precisely the
/// "bootstrap rejected before first paint" case under review.
Widget _jeebBootstrapFailed(Object error) {
  final Future<BootstrapResult> rejected = Future<BootstrapResult>.error(error);
  rejected.ignore();
  return JeebBootstrap(bootstrapFuture: rejected);
}

/// The payload behind [jeebBootstrapFailedOpaque].
///
/// Exported (like the three below) so the render test can assert the exact
/// string this preview puts on screen without re-typing it — the error host
/// renders `'App failed to start: $error'`, so the payload IS the state.
final Object jeebBootstrapOpaqueError = Exception();

/// The payload behind [jeebBootstrapFailedMissingPlugin].
final Object jeebBootstrapMissingPluginError = MissingPluginException(
  'No implementation found for method getAll on channel '
  'plugins.flutter.io/shared_preferences',
);

/// The payload behind [jeebBootstrapFailedVerbose].
final Object jeebBootstrapVerboseError = PlatformException(
  code: 'channel-error',
  message: 'Unable to establish connection on channel: '
      '"dev.flutter.pigeon.shared_preferences_android'
      '.SharedPreferencesApi.getAll".',
  details: 'Lost connection to device before the reply was received.',
  stacktrace: 'java.lang.IllegalStateException: Reply already submitted\n'
      '\tat io.flutter.plugin.common.BasicMessageChannel.reply\n'
      '\tat io.flutter.embedding.engine.dart.DartMessenger.handleMessage',
);

/// The payload behind [jeebBootstrapFailedArabicPayload].
final Object jeebBootstrapArabicError =
    Exception('تعذّر الوصول إلى مساحة التخزين المحلية');

/// Cold start: the branded splash, held while `Bootstrap.minimal()` runs.
///
/// The state every launch passes through. Worth a preview because the splash
/// host resolves its own theme and locale independently of the app: it reads
/// `PlatformDispatcher.instance.locale` (prefs are not loaded yet) and
/// `ThemeMode.system`. Consequence for the reviewer: the **AR RTL dark**
/// rendering of THIS preview is not Arabic and not dark — the canvas locale and
/// brightness do not reach the inner `MaterialApp`, only the host machine's
/// locale and theme do. To see the mirrored splash, change the device/desktop
/// locale (or use the `holdSplash` + `forcedLocale` dev seams on a debug build).
@JeebPreview(group: 'app', name: 'Cold start (splash)', size: jeebBootstrapPreviewBox)
Widget jeebBootstrapColdStart() => _jeebBootstrapBootstrapping();

/// Shortest plausible failure: something threw a bare `Exception`.
///
/// Renders "App failed to start: Exception" — a dead end with no cause, no
/// retry, no support path, in hardcoded English. This is the floor of the error
/// host's design and the reason it is worth reviewing at all.
@JeebPreview(group: 'app', name: 'Boot failed · opaque', size: jeebBootstrapPreviewBox)
Widget jeebBootstrapFailedOpaque() => _jeebBootstrapFailed(jeebBootstrapOpaqueError);

/// The documented failure mode: the `SharedPreferences` platform channel is
/// gone, so `Bootstrap.minimal()` rejects.
///
/// This is the exact case the widget's own comment names ("Bootstrap failure is
/// unrecoverable (SharedPreferences platform channel is broken)"), and it is the
/// realistic middle of the range: ~110 characters of channel plumbing, which
/// still fits at 200% text (measured 480 dp in the 796 dp box) but reads as raw
/// internals rather than as anything a user can act on.
@JeebPreview(group: 'app', name: 'Boot failed · plugin missing', size: jeebBootstrapPreviewBox)
Widget jeebBootstrapFailedMissingPlugin() =>
    _jeebBootstrapFailed(jeebBootstrapMissingPluginError);

/// Longest plausible content: a native `PlatformException` carrying details AND
/// a stack trace, which is what the platform actually hands back on a failed
/// pigeon call.
///
/// The layout ceiling for this widget, and the one preview here that breaks.
/// The message sits in a `Center(Padding(Text))` with no
/// `SingleChildScrollView`, no `maxLines` and no `overflow`, so in the **EN
/// 200% text** rendering the paragraph needs 1520 dp inside a 796 dp box: over
/// half of it — the details and the whole stack trace — is clipped mid-word,
/// with no ellipsis to say so and no way to scroll to it. Nothing throws, which
/// is why only a rendering at large text (or the measurement in
/// `test/previews/app/jeeb_bootstrap_preview_test.dart`) catches it.
@JeebPreview(group: 'app', name: 'Boot failed · verbose', size: jeebBootstrapPreviewBox)
Widget jeebBootstrapFailedVerbose() => _jeebBootstrapFailed(jeebBootstrapVerboseError);

/// A failure whose message is not Latin script.
///
/// Native layers localize their own messages, so an Arabic device can put
/// Arabic in this string. The error host has no `locale`, no delegates and no
/// [Directionality] of its own, so it renders LTR whatever the payload: the
/// hardcoded English label and the Arabic message end up in one bidi run,
/// centred as if they read the same way. This is the state that shows the error
/// host is not merely unlocalized but actively wrong on an Arabic device.
@JeebPreview(group: 'app', name: 'Boot failed · Arabic payload', size: jeebBootstrapPreviewBox)
Widget jeebBootstrapFailedArabicPayload() => _jeebBootstrapFailed(jeebBootstrapArabicError);
