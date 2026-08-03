import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/settings_fakes.dart';

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
  double textScale = 1,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
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

  Future<SettingsCubit> loadedCubit({String phone = '+96170100200'}) async {
    final cubit = SettingsCubit(
      profileRepository: InMemoryProfileRepository(),
      accountService: const FakeAccountService(),
      fallbackPhoneE164: phone,
    );
    await cubit.load();
    return cubit;
  }

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  group('SettingsScreen — sections', () {
    testWidgets('renders identity, language, notifications, more, account',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      final semantics = tester.ensureSemantics();
      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      // The redesign replaces the "Profile" section header with the navy
      // identity card; the row itself keeps its key.
      expect(find.byKey(const Key('settings-row-profile')), findsOneWidget);
      // JeebSectionLabel uppercases in EN.
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      // The About section is gone: the version moved into the footer line.
      expect(
        find.bySemanticsIdentifier('logout_delete_account_root'),
        findsOneWidget,
      );
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      expect(find.textContaining('1.2.3'), findsOneWidget);
      // The handle must be released inside the body: teardown runs after the
      // framework's leaked-handle verification.
      semantics.dispose();
    });

    testWidgets('notification rows are one line — no category subtitles',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('settings-screen-list'))),
      );
      expect(find.text(l10n.notificationCategoryOffers), findsOneWidget);
      expect(
        find.text(l10n.notificationCategoryOffersSubtitle),
        findsNothing,
        reason: 'the board draws one line per toggle row',
      );
    });

    testWidgets('Arabic locale renders RTL labels', (tester) async {
      await useTallSurface(tester);
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
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

    testWidgets('every frozen semantics identifier survives the rebuild',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      final semantics = tester.ensureSemantics();
      Diag.enabledOverride = true;
      addTearDown(() => Diag.enabledOverride = null);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      const frozen = <String>[
        'settings-profile-row',
        'settings-row-become-jeeber',
        'settings_open_addresses',
        'settings_language_en_option',
        'settings_language_ar_option',
        'settings_notifications_offers_toggle',
        'settings_notifications_chat_toggle',
        'settings_notifications_status_toggle',
        'settings_notifications_ratings_toggle',
        'settings-row-notifications-manage',
        'settings_open_diagnostics',
        'logout_delete_account_root',
        'settings_delete_account_row',
        'settings_sign_out_row',
        // New in the redesign (plan §5 #1 `<screen>_back`).
        'settings_back',
      ];
      for (final id in frozen) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: 'frozen identifier "$id" must still be emitted',
        );
      }
      semantics.dispose();
    });
  });

  group('SettingsScreen — language', () {
    testWidgets('tapping Arabic flips the LocaleCubit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
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
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      expect(cubit.state.notifications.offers, isTrue);
      await tester.tap(find.byKey(const Key('settings-row-notifications-offers')));
      await tester.pumpAndSettle();
      expect(cubit.state.notifications.offers, isFalse);
    });

    testWidgets('tapping the rating-reminders switch toggles cubit state',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      final before = cubit.state.notifications.ratingReminders;
      await tester
          .tap(find.byKey(const Key('settings-row-notifications-ratings')));
      await tester.pumpAndSettle();
      expect(cubit.state.notifications.ratingReminders, !before);
    });
  });

  group('SettingsScreen — more', () {
    testWidgets('diagnostics row is absent when Diag is off', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      Diag.enabledOverride = false;
      addTearDown(() => Diag.enabledOverride = null);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-row-diagnostics')), findsNothing);
      // The always-visible navigation rows stay.
      expect(find.byKey(const Key('settings-row-addresses')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-row-notifications-manage')),
        findsOneWidget,
      );
    });
  });

  group('SettingsScreen — destructive actions', () {
    testWidgets('delete-account and sign-out rows are present and enabled',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      // The destructive rows expose stable keys for QA and Maestro; the
      // cubit-level test covers the confirmed-action service interaction
      // since the confirm surface is a modal sheet.
      expect(find.byKey(const Key('settings-row-delete-account')),
          findsOneWidget);
      expect(find.byKey(const Key('settings-row-sign-out')), findsOneWidget);
    });

    testWidgets('delete-account row flips to pending after cubit emits',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      await useTallSurface(tester);
      await tester.pumpWidget(_harness(prefs: prefs, cubit: cubit));
      await tester.pumpAndSettle();

      await cubit.requestAccountDeletion();
      await tester.pumpAndSettle();

      // E20 (JEBV4-215): pending row now states the scheduled-purge reversal.
      expect(find.text('Scheduled for deletion. Sign in again to cancel.'),
          findsOneWidget);
    });
  });

  group('SettingsScreen — profile read-only phone', () {
    testWidgets('identity card shows the phone when the name is empty',
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

      // The subtitle is one Text ("<phone> · Edit profile"), and the phone is
      // wrapped in an LTR isolate — the isolate chars bracket the run, they do
      // not intersperse, so a substring match still resolves.
      expect(find.textContaining('+96170555888'), findsOneWidget);
    });

    testWidgets('the phone stays LTR-isolated under Arabic', (tester) async {
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
      await tester.pumpWidget(_harness(
        prefs: prefs,
        cubit: cubit,
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('\u2066+96170555888\u2069'),
        findsOneWidget,
        reason: 'an E.164 number must not reorder inside an RTL line',
      );
    });
  });

  group('SettingsScreen — layout', () {
    testWidgets('200% text scale on a 360x640 surface does not overflow',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final cubit = await loadedCubit();
      addTearDown(cubit.close);

      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _harness(prefs: prefs, cubit: cubit, textScale: 2),
      );
      await tester.pumpAndSettle();

      // The sticky-footer structure (IntrinsicHeight + Spacer inside the list)
      // must grow the column past the viewport rather than clip the footer.
      expect(tester.takeException(), isNull);
    });
  });
}
