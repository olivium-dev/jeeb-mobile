import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_rating.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this.arb);

  final String arb;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, arb);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

void main() {
  testWidgets('cold-start profile reflects the real review count', (
    tester,
  ) async {
    final delegate = _SyncDelegate(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: CustomerProfileRating(rating: null, ratingCount: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 Reviews'), findsOneWidget);
    expect(find.text('No reviews yet'), findsNothing);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('an unreadable rating says so, never "No reviews yet" (UX-33)', (
    tester,
  ) async {
    final delegate = _SyncDelegate(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: CustomerProfileRating(
            rating: null,
            ratingCount: 0,
            ratingUnavailable: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });
}
