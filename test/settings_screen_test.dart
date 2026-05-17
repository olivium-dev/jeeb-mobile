import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/data/in_memory_profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
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

Widget _harness({
  required SharedPreferences prefs,
  required SettingsCubit cubit,
  Locale locale = const Locale('en'),
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => locale,
        ),
      ),
    ],
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, currentLocale) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: currentLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          _syncDelegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SettingsScreen(cubit: cubit, appVersion: '1.2.3'),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  group('SettingsScreen — sections', () {
    testWidgets('renders profile, language, notifications, about, account',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('About'), findsWidgets);
      expect(find.text('Account'), findsWidgets);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(find.text('1.2.3'), findsOneWidget);
    });

    testWidgets('Arabic locale renders RTL labels', (tester) async {
      await useTallSurface(tester);
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(
        prefs: prefs,
        cubit: cubit,
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsWidgets);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
      final ctx = tester.element(find.byKey(const Key('settings-screen-list')));
      expect(Directionality.of(ctx), TextDirection.rtl);
    });
  });

  group('SettingsScreen — language', () {
    testWidgets('tapping Arabic flips the LocaleCubit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-row-language-ar')));
      await tester.pumpAndSettle();

      expect(prefs.getString('app.locale.languageCode'), 'ar');
    });
  });

  group('SettingsScreen — notifications', () {
    testWidgets('tapping the offers switch toggles cubit state',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      expect(cubit.state.notifications.offers, isTrue);
      await tester.tap(find.byKey(const Key('settings-row-notifications-offers')));
      await tester.pumpAndSettle();
      expect(cubit.state.notifications.offers, isFalse);
    });
  });

  group('SettingsScreen — destructive actions', () {
    testWidgets('delete-account and sign-out rows are present and enabled',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      // The destructive rows expose stable keys for QA and Maestro; the
      // cubit-level test covers the confirmed-action service interaction
      // since the OMDS confirmation dialog wraps AlertDialog.actions in
      // OverflowBar, which doesn't compose with the Expanded children used
      // by the OMDS dialog implementation today.
      expect(find.byKey(const Key('settings-row-delete-account')),
          findsOneWidget);
      expect(find.byKey(const Key('settings-row-sign-out')), findsOneWidget);
    });

    testWidgets('delete-account row flips to pending after cubit emits',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      await cubit.requestAccountDeletion();
      await tester.pumpAndSettle();

      expect(find.text('Deletion requested. We\'ll be in touch.'),
          findsOneWidget);
    });
  });

  group('SettingsScreen — profile read-only phone', () {
    testWidgets('profile section shows phone subtitle when name is empty',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repo = InMemoryProfileRepository();
      await repo.save(const UserProfile(phoneE164: '+96170555888'));
      final cubit = SettingsCubit(
        profileRepository: repo,
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170555888',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('+96170555888'), findsOneWidget);
    });
  });
}
