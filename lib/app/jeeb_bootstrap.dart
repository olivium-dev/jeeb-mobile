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

bool get _holdSplash => kDebugMode && DevSeam.current.holdSplash;

String get _forcedLocale => kDebugMode ? DevSeam.current.forcedLocale : '';

const Duration _startupTransitionDuration = Duration(milliseconds: 350);

class JeebBootstrap extends StatefulWidget {
  const JeebBootstrap({
    super.key,
    Future<BootstrapResult>? bootstrapFuture,
    Duration? minSplashHold,
  }) : _override = bootstrapFuture,
       _minSplashHold = minSplashHold;

  final Future<BootstrapResult>? _override;

  final Duration? _minSplashHold;

  @override
  State<JeebBootstrap> createState() => _JeebBootstrapState();
}

class _JeebBootstrapState extends State<JeebBootstrap> {
  late final Future<BootstrapResult> _bootstrap =
      widget._override ?? Bootstrap.minimal();

  bool _minHoldElapsed = false;
  bool _entranceElapsed = false;
  bool _revealed = false;
  bool _overlayMounted = true;
  bool _revealScheduled = false;
  Timer? _holdTimer;
  Timer? _entranceTimer;

  bool _deferredScheduled = false;

  @override
  void initState() {
    super.initState();
    final hold = widget._minSplashHold;
    if (hold == null || hold <= Duration.zero) {
      _minHoldElapsed = true;
    } else {
      _holdTimer = Timer(hold, () {
        if (!mounted) return;
        setState(() => _minHoldElapsed = true);
      });
    }
    _entranceTimer = Timer(BrandedSplash.entranceDuration, () {
      if (!mounted) return;
      setState(() => _entranceElapsed = true);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _entranceTimer?.cancel();
    super.dispose();
  }

  void _scheduleDeferred(BootstrapResult result) {
    if (_deferredScheduled) return;
    _deferredScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Bootstrap.deferred(crashReporter: result.crashReporter);
    });
  }

  bool get _reduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  void _scheduleReveal() {
    if (_revealed || _revealScheduled) return;
    _revealScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _revealed = true;
        if (_reduceMotion) {
          _overlayMounted = false;
        }
      });
    });
  }

  void _removeOverlay() {
    if (_revealed && mounted) setState(() => _overlayMounted = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapErrorApp(error: snapshot.error!);
        }

        final bootstrapping = snapshot.connectionState != ConnectionState.done;
        final result = bootstrapping ? null : snapshot.requireData;
        if (result != null) _scheduleDeferred(result);

        final readyToReveal =
            result != null &&
            (_reduceMotion || _entranceElapsed) &&
            _minHoldElapsed &&
            !_holdSplash;
        if (readyToReveal) _scheduleReveal();

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[
            if (result == null)
              const SizedBox.expand()
            else
              IgnorePointer(
                ignoring: !_revealed,
                child: ExcludeSemantics(
                  excluding: !_revealed,
                  child: JeebApp(
                    preferences: result.preferences,
                    crashReporter: result.crashReporter,
                  ),
                ),
              ),
            if (_overlayMounted)
              AnimatedOpacity(
                opacity: _revealed ? 0 : 1,
                duration: _reduceMotion
                    ? Duration.zero
                    : _startupTransitionDuration,
                curve: Curves.easeInOut,
                onEnd: _removeOverlay,
                child: IgnorePointer(
                  ignoring: _revealed,
                  child: ExcludeSemantics(
                    excluding: _revealed,
                    child: const _SplashApp(key: ValueKey<String>('splash')),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SplashApp extends StatelessWidget {
  const _SplashApp({super.key});

  static Locale _initialLocale() {
    final forced = _forcedLocale;
    final candidate = forced.isNotEmpty
        ? forced
        : PlatformDispatcher.instance.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == candidate,
    );
    return supported ? Locale(candidate) : const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Pinned: the splash is the first painted surface, so `system` here is
      // where a light-mode device flashes white.
      theme: AppTheme.midnight(),
      darkTheme: AppTheme.midnight(),
      themeMode: ThemeMode.dark,
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
      // An unthemed MaterialApp renders stock Material white.
      theme: AppTheme.midnight(),
      darkTheme: AppTheme.midnight(),
      themeMode: ThemeMode.dark,
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

/// This widget owns the whole viewport, so the canvas box is a phone, not a
/// component slot: 390×844 is the iPhone 14 / Galaxy S22 logical frame the
const Size jeebBootstrapPreviewBox = Size(390, 844);

/// A bootstrap future that never completes — the honest model of "init is still
/// running", and the only way to hold the splash on screen indefinitely without
Widget _jeebBootstrapBootstrapping() =>
    JeebBootstrap(bootstrapFuture: Completer<BootstrapResult>().future);

/// A bootstrap future that rejects with [error], which routes straight to the
/// error host: `FutureBuilder` reports `hasError` before it reports `done`, so
Widget _jeebBootstrapFailed(Object error) {
  final Future<BootstrapResult> rejected = Future<BootstrapResult>.error(error);
  rejected.ignore();
  return JeebBootstrap(bootstrapFuture: rejected);
}

/// The payload behind [jeebBootstrapFailedOpaque].
/// Exported (like the three below) so the render test can assert the exact
final Object jeebBootstrapOpaqueError = Exception();

/// The payload behind [jeebBootstrapFailedMissingPlugin].
final Object jeebBootstrapMissingPluginError = MissingPluginException(
  'No implementation found for method getAll on channel '
  'plugins.flutter.io/shared_preferences',
);

/// The payload behind [jeebBootstrapFailedVerbose].
final Object jeebBootstrapVerboseError = PlatformException(
  code: 'channel-error',
  message:
      'Unable to establish connection on channel: '
      '"dev.flutter.pigeon.shared_preferences_android'
      '.SharedPreferencesApi.getAll".',
  details: 'Lost connection to device before the reply was received.',
  stacktrace:
      'java.lang.IllegalStateException: Reply already submitted\n'
      '\tat io.flutter.plugin.common.BasicMessageChannel.reply\n'
      '\tat io.flutter.embedding.engine.dart.DartMessenger.handleMessage',
);

/// The payload behind [jeebBootstrapFailedArabicPayload].
final Object jeebBootstrapArabicError = Exception(
  'تعذّر الوصول إلى مساحة التخزين المحلية',
);

/// Cold start: the branded splash, held while `Bootstrap.minimal()` runs.
/// The state every launch passes through. Worth a preview because the splash
@JeebPreview(
  group: 'app',
  name: 'Cold start (splash)',
  size: jeebBootstrapPreviewBox,
)
Widget jeebBootstrapColdStart() => _jeebBootstrapBootstrapping();

/// Shortest plausible failure: something threw a bare `Exception`.
/// Renders "App failed to start: Exception" — a dead end with no cause, no
@JeebPreview(
  group: 'app',
  name: 'Boot failed · opaque',
  size: jeebBootstrapPreviewBox,
)
Widget jeebBootstrapFailedOpaque() =>
    _jeebBootstrapFailed(jeebBootstrapOpaqueError);

/// The documented failure mode: the `SharedPreferences` platform channel is
/// gone, so `Bootstrap.minimal()` rejects.
@JeebPreview(
  group: 'app',
  name: 'Boot failed · plugin missing',
  size: jeebBootstrapPreviewBox,
)
Widget jeebBootstrapFailedMissingPlugin() =>
    _jeebBootstrapFailed(jeebBootstrapMissingPluginError);

/// Longest plausible content: a native `PlatformException` carrying details AND
/// a stack trace, which is what the platform actually hands back on a failed
@JeebPreview(
  group: 'app',
  name: 'Boot failed · verbose',
  size: jeebBootstrapPreviewBox,
)
Widget jeebBootstrapFailedVerbose() =>
    _jeebBootstrapFailed(jeebBootstrapVerboseError);

/// A failure whose message is not Latin script.
/// Native layers localize their own messages, so an Arabic device can put
@JeebPreview(
  group: 'app',
  name: 'Boot failed · Arabic payload',
  size: jeebBootstrapPreviewBox,
)
Widget jeebBootstrapFailedArabicPayload() =>
    _jeebBootstrapFailed(jeebBootstrapArabicError);
