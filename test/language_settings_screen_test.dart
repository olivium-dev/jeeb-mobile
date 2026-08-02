import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

Widget _harness(LocaleCubit cubit) {
  return BlocProvider.value(
    value: cubit,
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) => MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LanguageSettingsScreen(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders both language rows with the active one checked',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language-row-en')), findsOneWidget);
    expect(find.byKey(const Key('language-row-ar')), findsOneWidget);

    // English is active, so its row carries the check mark while the Arabic
    final englishCheck = find.descendant(
      of: find.byKey(const Key('language-row-en')),
      matching: find.byIcon(Icons.check),
    );
    final arabicCheck = find.descendant(
      of: find.byKey(const Key('language-row-ar')),
      matching: find.byIcon(Icons.check),
    );
    expect(englishCheck, findsOneWidget);
    expect(arabicCheck, findsNothing);
  });

  testWidgets('tapping Arabic flips strings, RTL, and persists the choice',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    // Sanity: starts in English, LTR.
    expect(find.text('Language'), findsWidgets);

    await tester.tap(find.byKey(const Key('language-row-ar')));
    await tester.pumpAndSettle();

    // Strings are now Arabic and the directionality is RTL.
    expect(find.text('اللغة'), findsWidgets);
    final direction = Directionality.of(
      tester.element(find.byKey(const Key('language-settings-list'))),
    );
    expect(direction, TextDirection.rtl);

    // Persistence: the cubit wrote the choice to shared_preferences so the
    expect(prefs.getString('app.locale.languageCode'), 'ar');

    // The check mark moved to the Arabic row.
    final arabicCheck = find.descendant(
      of: find.byKey(const Key('language-row-ar')),
      matching: find.byIcon(Icons.check),
    );
    final englishCheck = find.descendant(
      of: find.byKey(const Key('language-row-en')),
      matching: find.byIcon(Icons.check),
    );
    expect(arabicCheck, findsOneWidget);
    expect(englishCheck, findsNothing);
  });

  testWidgets('tapping the already-selected language is a no-op',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    final localeBefore = cubit.state;
    await tester.tap(find.byKey(const Key('language-row-en')));
    await tester.pump();

    // No emission means no state change — the cubit reference is stable.
    expect(identical(cubit.state, localeBefore), isTrue);
    // The pref must not have been written either — re-tapping English when it
    expect(prefs.getString('app.locale.languageCode'), isNull);
  });
}
