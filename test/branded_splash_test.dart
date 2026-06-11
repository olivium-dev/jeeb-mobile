import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Loads the real ARB files synchronously so the splash sees the same strings
/// it ships with (mirrors the pattern in client_home_screen_test.dart).
class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  _syncDelegate = _SyncDelegate({
    'en': File('lib/l10n/app_en.arb').readAsStringSync(),
    'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
  });
}

Widget _harness({Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const BrandedSplash(),
  );
}

void main() {
  setUpAll(_loadArbs);

  testWidgets('renders the bundled logo SVG and localized EN tagline',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Delivery App'), findsOneWidget);
  });

  testWidgets('exposes Semantics identifiers for QA targeting',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    for (final id in const ['_splash_screen', '_splash_logo', '_splash_tagline']) {
      expect(
        find.bySemanticsIdentifier(id),
        findsOneWidget,
        reason: 'missing Semantics(identifier: "$id")',
      );
    }
  });

  testWidgets('uses the secondary-container color role for the background',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    final navy = AppTheme.light().colorScheme.secondaryContainer;
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(BrandedSplash),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, navy);
  });

  testWidgets('mirrors to RTL and shows the Arabic tagline in ar locale',
      (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pump();

    expect(find.text('تطبيق التوصيل'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(BrandedSplash)));
    expect(dir, TextDirection.rtl);
  });
}
