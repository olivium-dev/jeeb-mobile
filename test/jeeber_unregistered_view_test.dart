import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host(VoidCallback onRegister, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: JeeberUnregisteredView(onRegister: onRegister, profileName: 'Kamal'),
    ),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets('renders localized upsell copy (no hardcoded strings)',
      (tester) async {
    await tester.pumpWidget(_host(() {}));
    await tester.pumpAndSettle();

    expect(find.text('Register as a delivery man'), findsOneWidget);
    expect(find.text('Start earning money'), findsOneWidget);
    expect(find.text('Register now'), findsOneWidget);
  });

  testWidgets('register CTA fires onRegister', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(() => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(JeeberUnregisteredView.registerButtonKey));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('renders Arabic copy under RTL', (tester) async {
    await tester.pumpWidget(_host(() {}, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    final dir = Directionality.of(
      tester.element(find.byKey(JeeberUnregisteredView.rootKey)),
    );
    expect(dir, TextDirection.rtl);
    expect(find.text('سجّل كموصِّل'), findsOneWidget);
    expect(find.text('سجّل الآن'), findsOneWidget);
  });
}
