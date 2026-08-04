/// M6 accent-budget guards for `home_client/`.
///
/// The progress bar is the "orange spinner" signature: `progressIndicatorTheme`
/// already inks bare indicators periwinkle, so an explicit `valueColor` was the
/// one override that escaped the theme.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/active_request_card.dart';
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

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.midnight(),
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() {
    _delegate = _SyncLocDelegate(<String, String>{
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  testWidgets('the active-order progress bar is theme-inked, never orange',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(ActiveOrderCard(
      request: const ClientHomeRequest(
        id: 'r-1',
        title: 'Pharmacy run',
        status: ClientRequestStatus.enRoute,
        destinationLabel: 'Achrafieh',
        progressStep: 2,
        tier: ClientRequestTier.flash,
      ),
      onTap: () {},
      onOpenChat: () {},
    )));
    await tester.pump();

    final LinearProgressIndicator bar =
        tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    // No local override at all: the bar must inherit `progressIndicatorTheme`.
    expect(bar.valueColor, isNull);
    expect(bar.backgroundColor, isNull);

    final ProgressIndicatorThemeData indicators = Theme.of(
      tester.element(find.byType(LinearProgressIndicator)),
    ).progressIndicatorTheme;
    expect(indicators.color, JeebMidnight.inkMuted);
    expect(indicators.color, isNot(_scheme.tertiary));
  });
}
