// M4 — the `kyc-status` deep-link stub.
//
// Was `OmdsEmptyStatePage` with two hard-coded English strings and a Material
// `construction_outlined` glyph, on no Midnight field. It is still honestly a
// STUB: the copy now comes from the two shipped `kycStatus*` keys, which say
// the status will appear here.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/deep_link_targets/kyc_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _host({Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const KycStatusScreen(),
    );

void main() {
  testWidgets('M4: the stub is the §2.7 EMPTY member on radar', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final JeebEmptyState state =
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(state.status, JeebEmptyStateStatus.empty);
    // A verification status is a wait on the reviewer, and radar is the one
    // tile that draws no microphone.
    expect(state.variant, JeebEmptyStateVariant.radar);
    expect(state.identifier, 'deep_link_kyc_status_root');
    expect(find.byIcon(Icons.construction_outlined), findsNothing);
  });

  testWidgets('M4: the hard-coded English is gone in BOTH locales',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    final AppLocalizations en =
        AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));
    expect(find.text(en.kycStatusTitle), findsOneWidget);
    expect(find.text(en.kycStatusPlaceholder), findsOneWidget);
    expect(find.text('KYC Status coming soon'), findsNothing);
    expect(find.text('This screen is not yet available.'), findsNothing);

    await tester.pumpWidget(_host(locale: const Locale('ar')));
    await tester.pump();
    final AppLocalizations ar =
        AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));
    expect(ar.kycStatusTitle, isNot(en.kycStatusTitle));
    expect(find.text(ar.kycStatusTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(JeebEmptyState))),
      TextDirection.rtl,
    );
  });

  testWidgets('M4: it brings its own Midnight field, transparent scaffold',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byType(JeebMidnightField), findsOneWidget);
    final Scaffold scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(JeebMidnightField),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, Colors.transparent);
  });
}
