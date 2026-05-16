import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _LocaleProbe extends StatelessWidget {
  const _LocaleProbe();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    return Column(
      children: [
        Text(l10n.navHome, key: const Key('label-home')),
        Text(
          direction == TextDirection.rtl ? 'dir:rtl' : 'dir:ltr',
          key: const Key('label-dir'),
        ),
      ],
    );
  }
}

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
        home: const Scaffold(body: _LocaleProbe()),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Initial locale falls back to English when device locale is unsupported',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('fr'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('dir:ltr'), findsOneWidget);
  });

  testWidgets('Device locale Arabic auto-selected on first launch with RTL',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('ar', 'SA'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('dir:rtl'), findsOneWidget);
  });

  testWidgets('setLocale flips strings and direction without restart',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('dir:ltr'), findsOneWidget);

    await cubit.setLocale(const Locale('ar'));
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('dir:rtl'), findsOneWidget);
    expect(prefs.getString('app.locale.languageCode'), 'ar');

    // And back to English in the same app instance.
    await cubit.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('dir:ltr'), findsOneWidget);
  });

  testWidgets('Persisted locale wins over device locale',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.locale.languageCode': 'ar',
    });
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('dir:rtl'), findsOneWidget);
  });
}
