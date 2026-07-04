// JEBV4-13: the OfflineBanner's DISMISS action was `onTap: () {}` — a dead
// CTA (atlas P1 #18 dead-CTA class). This suite proves the dismissal is real
// and re-arms per offline episode, and that the copy is localized.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';
import 'package:jeeb_mobile/features/offline_mode/presentation/offline_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);
  final String _arb;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

void _loadArb() {
  _delegate = _SyncDelegate(File('lib/l10n/app_en.arb').readAsStringSync());
}

Widget _host(OfflineCubit cubit) {
  return BlocProvider<OfflineCubit>.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: Column(children: [OfflineBanner()])),
    ),
  );
}

void main() {
  setUpAll(_loadArb);

  testWidgets(
      'DISMISS actually hides the banner and a NEW offline episode re-arms it',
      (tester) async {
    final cubit = OfflineCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);

    cubit.setOffline();
    await tester.pump();
    expect(find.byType(MaterialBanner), findsOneWidget);

    // Previously a no-op: tapping DISMISS left the banner up forever.
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsNothing);
    expect(cubit.state.bannerDismissed, isTrue);

    // Back online, then a NEW outage → the banner must return.
    cubit.setOnline();
    await tester.pump();
    cubit.setOffline();
    await tester.pump();
    expect(find.byType(MaterialBanner), findsOneWidget);
  });
}
