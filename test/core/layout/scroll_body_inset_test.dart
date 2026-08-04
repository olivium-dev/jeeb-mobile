import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/layout/bottom_inset.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/dev_client_home_fixtures.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/settings_fakes.dart';

/// Representative 3-button soft-nav inset (~48dp). Any correct edge-to-edge
/// fix must reserve at least this much at the bottom of a scroll body so the
const double _kNavBarInsetDp = 48;

void main() {
  group('BottomInsetX.scrollBodyBottomInset', () {
    // Seeds the system nav-bar inset on the FlutterView and reads it back
    Future<double> resolveInset(
      WidgetTester tester, {
      required double navBarDp,
      bool wrapInSafeArea = false,
    }) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: navBarDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: navBarDp * dpr);
      addTearDown(tester.view.reset);

      late double captured;
      Widget probe = Builder(
        builder: (context) {
          captured = context.scrollBodyBottomInset;
          return const SizedBox();
        },
      );
      if (wrapInSafeArea) {
        probe = SafeArea(child: probe);
      }

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view),
          child: probe,
        ),
      );
      return captured;
    }

    testWidgets('reserves the nav-bar inset for a full-screen scroll body',
        (tester) async {
      final inset =
          await resolveInset(tester, navBarDp: _kNavBarInsetDp);
      expect(inset, _kNavBarInsetDp);
    });

    testWidgets('is zero with no nav bar (gesture nav off)', (tester) async {
      final inset = await resolveInset(tester, navBarDp: 0);
      expect(inset, 0);
    });

    testWidgets('is double-pad safe — returns 0 once SafeArea consumes it',
        (tester) async {
      // If an ancestor SafeArea already reserved the bottom inset, the helper
      final inset = await resolveInset(
        tester,
        navBarDp: _kNavBarInsetDp,
        wrapInSafeArea: true,
      );
      expect(inset, 0);
    });
  });

  group('Settings list reserves the bottom nav inset (edge-to-edge)', () {
    late _SyncDelegate delegate;

    setUpAll(() {
      delegate = _SyncDelegate(
        {
          'en': File('lib/l10n/app_en.arb').readAsStringSync(),
          'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
        },
      );
    });

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('settings ListView bottom padding includes the nav-bar inset',
        (tester) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      addTearDown(tester.view.reset);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(
        profileRepository: InMemoryProfileRepository(),
        accountService: const FakeAccountService(),
        fallbackPhoneE164: '+96170100200',
      );
      await cubit.load();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => LocaleCubit(
                prefs: prefs,
                deviceLocaleProvider: () => const Locale('en'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SettingsScreen(cubit: cubit, appVersion: '1.2.3'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(
        find.byKey(const Key('settings-screen-list')),
      );
      final padding = listView.padding! as EdgeInsets;
      expect(
        padding.bottom,
        greaterThanOrEqualTo(_kNavBarInsetDp),
        reason: 'Settings list must reserve the $_kNavBarInsetDp dp nav-bar '
            'inset so the final Account row clears the soft buttons; bottom '
            'padding was ${padding.bottom}',
      );
      // Horizontal gutter preserved.
      expect(padding.left, 16);
      expect(padding.right, 16);
    });
  });

  group('Client home list reserves the bottom nav inset (edge-to-edge)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    late _SyncDelegate delegate;

    setUpAll(() {
      delegate = _SyncDelegate(
        {
          'en': File('lib/l10n/app_en.arb').readAsStringSync(),
          'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
        },
      );
    });

    testWidgets(
        'ready-layout ListView bottom padding includes the nav-bar inset',
        (tester) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.viewPadding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      tester.view.padding = FakeViewPadding(bottom: _kNavBarInsetDp * dpr);
      addTearDown(tester.view.reset);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Mirror the proven client_home_screen_test harness: create the cubit
      final repo = InMemoryClientHomeRepository.fromSnapshot(
        DevClientHomeFixtures.snapshot(),
        latency: Duration.zero,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: BlocProvider(
              create: (_) => ClientHomeCubit(
                repository: repo,
                greetingNameProvider: () => 'Sami',
              ),
              child: const ClientHomeScreen(
                initialTab: ClientHomeTab.inProgress,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The ready-layout ListView reserves twoXLarge (32) + the nav inset.
      final listViews = tester
          .widgetList<ListView>(find.byType(ListView))
          .where((lv) => lv.padding is EdgeInsets)
          .toList();
      final reserved = listViews.any((lv) {
        final p = lv.padding! as EdgeInsets;
        return p.bottom >= _kNavBarInsetDp;
      });
      expect(
        reserved,
        isTrue,
        reason: 'A home ListView must reserve at least the $_kNavBarInsetDp dp '
            'nav-bar inset so the last order card clears the bottom nav bar.',
      );
    });
  });
}

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}
