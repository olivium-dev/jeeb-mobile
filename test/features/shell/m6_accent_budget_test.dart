/// M6 accent-budget guards for `shell/`.
/// R1 draws BOTH persistent header glyphs white; the wallet chip was the one
/// orange on every customer header.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/shell/widgets/shell_header_actions.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

const ColorScheme _scheme = AppTheme.midnightScheme;

class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arb);

  final Map<String, String> _arb;

  @override
  bool isSupported(Locale locale) => _arb.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb[locale.languageCode]!);

  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void main() {
  setUpAll(() {
    _delegate = _SyncLocDelegate(<String, String>{
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  testWidgets('both persistent header glyphs are white',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.midnight(),
      home: const Scaffold(body: ShellHeaderActions(idPrefix: 'orders_home')),
    ));
    await tester.pump();

    Color glyphOf(String id) => tester
        .widget<Icon>(
          find.descendant(
            of: find.bySemanticsIdentifier(id),
            matching: find.byType(Icon),
          ),
        )
        .color!;

    expect(glyphOf('orders_home_wallet_chip'), _scheme.onSurface);
    expect(glyphOf('orders_home_wallet_chip'), isNot(_scheme.primary));
    expect(glyphOf('orders_home_bell'), _scheme.onSurface);
  });
}
