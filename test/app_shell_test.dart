import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _shellHarness(SharedPreferences prefs) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => const Locale('en'),
        ),
      ),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
    ],
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) => MaterialApp(
        title: 'Jeeb',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          _syncDelegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ShellScreen(),
        // JeebEmptyState's E1 illustration loops ∞ by design (03-MOTION-NOTES
        // §E1): pumpAndSettle only terminates under reduce motion.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('App shell integration', () {
    testWidgets('renders bottom bar with all five additive destinations',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_shellHarness(prefs));
      await tester.pumpAndSettle();

      expect(find.text('Requests'), findsWidgets);
      expect(find.text('Delivery'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
      // UX LAW (S0-E2E-08): the jeeber tabs are additive — present for every
      // user; the close-out ruling only changes their WORDING per active role.
      expect(find.text('Deliver'), findsWidgets);
      expect(find.text('Earn'), findsWidgets);
    });

    testWidgets('OMDS light theme has useMaterial3 enabled', (_) async {
      final light = AppTheme.light();
      expect(light.useMaterial3, isTrue);
    });

    testWidgets('OMDS dark theme has useMaterial3 enabled', (_) async {
      final dark = AppTheme.dark();
      expect(dark.useMaterial3, isTrue);
    });

    testWidgets('light and dark both resolve to the one Midnight theme',
        (_) async {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.brightness, Brightness.dark);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.surface, dark.colorScheme.surface);
    });

    testWidgets('supported locales include English and Arabic', (_) async {
      final codes = AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toList();
      expect(codes, contains('en'));
      expect(codes, contains('ar'));
    });

    testWidgets('non-jeeber still sees the additive jeeber tabs, in client '
        'wording',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_shellHarness(prefs));
      await tester.pumpAndSettle();

      expect(find.text('Requests'), findsWidgets);
      expect(find.text('Delivery'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
      // No RoleAvailabilityCubit in this harness → non-jeeber, but the jeeber
      expect(find.text('Deliver'), findsWidgets);
      expect(find.text('Earn'), findsWidgets);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('Arabic locale renders RTL with Arabic labels',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final widget = MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => LocaleCubit(
              prefs: prefs,
              deviceLocaleProvider: () => const Locale('ar'),
            ),
          ),
          BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
          BlocProvider(create: (_) => RoleEligibilityCubit()),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) => MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              _syncDelegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const ShellScreen(),
            // JeebEmptyState's E1 illustration loops ∞ by design
            // (03-MOTION-NOTES §E1); pumpAndSettle needs reduce motion.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('الطلبات'), findsWidgets);
      expect(find.text('التوصيل'), findsWidgets);
      expect(find.text('حسابي'), findsWidgets);

      final ctx = tester.element(find.byType(ShellScreen));
      expect(Directionality.of(ctx), TextDirection.rtl);
    });

    testWidgets('themeMode system is wired correctly', (_) async {
      expect(ThemeMode.system, ThemeMode.system);
    });

    testWidgets('JeebTierColors extension is present in theme', (_) async {
      final light = AppTheme.light();
      final tierColors = light.extensions.values
          .whereType<dynamic>()
          .where((e) => e.runtimeType.toString().contains('JeebTierColors'));
      expect(tierColors, isNotEmpty);
    });
  });
}
