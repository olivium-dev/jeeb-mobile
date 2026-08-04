import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Test-only [LocalizationsDelegate] that reads ARB files synchronously
/// from the filesystem. The production delegate uses
/// `rootBundle.loadString` which doesn't reliably complete inside
class SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const SyncAppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) {
    final tag = locale.languageCode;
    final arb = File('lib/l10n/app_$tag.arb').readAsStringSync();
    return SynchronousFuture<AppLocalizations>(
      debugLoadAppLocalizationsSync(locale, arb),
    );
  }

  @override
  bool shouldReload(SyncAppLocalizationsDelegate old) => false;
}

Widget wrapForTest(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: ThemeData.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}
