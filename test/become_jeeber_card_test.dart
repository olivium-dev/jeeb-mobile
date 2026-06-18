import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/become_jeeber_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

Widget _host({required bool isAlreadyJeeber, VoidCallback? onTap}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: BecomeJeeberCard(
        isAlreadyJeeber: isAlreadyJeeber,
        onTap: onTap ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('AC1: card is visible for Client user without Jeeber role', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isAlreadyJeeber: false));
    await tester.pumpAndSettle();

    expect(find.byKey(BecomeJeeberCard.rootKey), findsOneWidget);
    expect(find.byKey(BecomeJeeberCard.ctaKey), findsOneWidget);
  });

  testWidgets('AC2: card is hidden when user already has Jeeber role', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isAlreadyJeeber: true));
    await tester.pumpAndSettle();

    expect(find.byKey(BecomeJeeberCard.rootKey), findsNothing);
  });

  testWidgets('AC3: tapping the CTA calls onTap callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(isAlreadyJeeber: false, onTap: () => tapped = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BecomeJeeberCard.ctaKey));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('AC4: card has semantic label for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isAlreadyJeeber: false));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.byKey(BecomeJeeberCard.rootKey));
    expect(semantics.label, contains('Jeeber'));
  });
}
