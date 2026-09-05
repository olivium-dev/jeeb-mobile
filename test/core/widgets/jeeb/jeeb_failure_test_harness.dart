import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../../support/sync_app_localizations.dart';

/// The two locales every failure surface is asserted in.
const List<Locale> kFailureLocales = <Locale>[Locale('en'), Locale('ar')];

/// Mounts [child] on the real Midnight theme with real ARB copy, which is what
/// the failure kit resolves against — `wrapForTest` uses `ThemeData.light()`
/// and would assert Material defaults instead of the shipped role colours.
Widget wrapMidnight(
  Widget child, {
  Locale locale = const Locale('en'),
  bool scrollable = true,
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: scrollable ? SingleChildScrollView(child: child) : child,
    ),
  );
}

/// Reads the ARB the way the app does, so a test asserts the shipped string
/// rather than a copy of it.
AppLocalizations l10nOf(WidgetTester tester, Type hostType) =>
    AppLocalizations.of(tester.element(find.byType(hostType)));
