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

bool get _holdSplash => kDebugMode && DevSeam.current.holdSplash;

String get _forcedLocale => kDebugMode ? DevSeam.current.forcedLocale : '';


class JeebBootstrap extends StatefulWidget {
  const JeebBootstrap({
    super.key,
    Future<BootstrapResult>? bootstrapFuture,
    Duration? minSplashHold,
  })  : _override = bootstrapFuture,
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
  Timer? _holdTimer;

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
      Bootstrap.deferred(crashReporter: result.crashReporter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BootstrapResult>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapErrorApp(error: snapshot.error!);
        }
        final bootstrapping =
            snapshot.connectionState != ConnectionState.done;
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
