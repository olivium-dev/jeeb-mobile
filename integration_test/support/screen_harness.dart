// Shared harness for native, ISOLATED per-screen UI tests.
//
// Each screen test pumps ONE screen widget directly — no app boot, no router,
// no walking a flow — inside the exact chrome the real app uses
// (OmdsColorTokensProvider + MaterialApp + AppTheme + the real l10n delegates),
// then captures an on-device screenshot. This mirrors lib/app/app.dart:508-524.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

const _delegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

// The image surface must be converted before every screenshot: the integration
// binding reverts it to a live surface between tests on some emulators, so a
// once-per-process guard leaves every test after the first unable to shoot
// (StateError: "Call convertFlutterSurfaceToImage() before taking a
// screenshot"). Convert before each shot instead; when the surface is already
// an image, convertFlutterSurfaceToImage asserts — swallow that and proceed.
Future<void> _ensureSurface(IntegrationTestWidgetsFlutterBinding binding) async {
  try {
    await binding.convertFlutterSurfaceToImage();
  } catch (_) {
    // Already an image surface (or conversion is a no-op here) — ready to shoot.
  }
}

/// Wraps [screen] in the app's real theme + localization chrome, isolated.
Widget wrapScreen(Widget screen, {Locale locale = const Locale('en')}) {
  return OmdsColorTokensProvider(
    tokens: const OmdsColorTokens(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: screen,
    ),
  );
}

/// Pump [screen] isolated and screenshot it as `<name>.png`. Settles animations
/// first; falls back to a bounded pump when a screen never reaches steady state
/// (e.g. a perpetual shimmer/spinner) so the shot is still taken.
Future<void> pumpAndShoot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  Widget screen,
  String name, {
  Locale locale = const Locale('en'),
}) async {
  await _ensureSurface(binding);
  await tester.pumpWidget(wrapScreen(screen, locale: locale));
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 300),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 8));
  } catch (_) {
    // Perpetual animation (shimmer/spinner) — pump a few frames and shoot anyway.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  await binding.takeScreenshot(name);
}

/// Router variant — for screens that read `GoRouterState.of(context)` at build
/// (e.g. SupportTicketScreen). Pump a MaterialApp.router with the same chrome.
Future<void> pumpRouterAndShoot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  RouterConfig<Object> routerConfig,
  String name, {
  Locale locale = const Locale('en'),
}) async {
  await _ensureSurface(binding);
  await tester.pumpWidget(
    OmdsColorTokensProvider(
      tokens: const OmdsColorTokens(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: _delegates,
        routerConfig: routerConfig,
      ),
    ),
  );
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 300),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 8));
  } catch (_) {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  await binding.takeScreenshot(name);
}
