import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Builds a [GoRouter] that renders [child] at `/` and, for ANY other location
/// (a stray tap that pushes/replaces to some named route), falls back to
/// rendering [child] again via [GoRouter.errorBuilder]. This keeps a live
/// preview from ever crashing the tool on an unexpected navigation.
///
/// Create this ONCE per preview (hold it in the hosting State) — a GoRouter is
/// stateful and must not be rebuilt on every frame.
GoRouter buildDevPreviewRouter(Widget child) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => child),
    ],
    // Stray taps / unknown named routes must never crash the tool — just show
    // the previewed screen again.
    errorBuilder: (_, _) => child,
  );
}

/// Wraps a live preview screen in the app's real chrome — OMDS tokens, the real
/// AppTheme + l10n delegates — exactly like `screen_harness.dart`'s `wrapScreen`,
/// but over a [MaterialApp.router]. The Router ancestor is REQUIRED: screens
/// that wrap `RootAwareBackScope` / `BackButtonListener` read `Router.of(context)`
/// / `GoRouterState.of(context)` at build and would otherwise assert.
///
/// [router] must be a stable instance created via [buildDevPreviewRouter] (held
/// in the hosting State), so passing it here does NOT rebuild it per frame.
Widget devPreviewHost({
  required GoRouter router,
  required Locale locale,
  required bool dark,
}) {
  return OmdsColorTokensProvider(
    tokens: const OmdsColorTokens(),
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}
