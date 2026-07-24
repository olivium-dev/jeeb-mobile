// Regression guard for the ProfileEditScreen ProviderNotFoundException<SettingsCubit>
// crash (2026-07-24 emulator-re-execution crawl, spool emu-restore-01 idx
// 20/28, against the live MSI backend).
//
// ROOT CAUSE: `ProfileEditScreen` reads a screen-wide `SettingsCubit` via
// `context.read`/`context.watch` (profile_edit_screen.dart), on the
// documented assumption that it shares the cubit the parent settings list
// hosts. But go_router's nested `routes: [...]` under the `/settings`
// GoRoute (app_router.dart) only nests the URL PATH — `settings-profile`
// (`/settings/profile`) is still an INDEPENDENT Page pushed onto the
// Navigator, so it never inherited the `BlocProvider<SettingsCubit>` that
// LiveSettingsScreen/SettingsScreen host around their OWN subtree
// (live_settings_screen.dart / settings_screen.dart). Both repro paths from
// the crawl hit the identical provider-free context:
//   1. A direct deep-land on `/settings/profile`.
//   2. Real in-app navigation: `/settings` -> tap the Profile row -> push
//      named `settings-profile` (`_ProfileSection.onTap` in
//      settings_screen.dart calls `context.pushNamed('settings-profile')`).
//
// FIX: app_router.dart's `settings-profile` GoRoute now wraps
// `ProfileEditScreen` in its own `BlocProvider<SettingsCubit>`, scoped to
// just that route, backed by the same real (non-fake) collaborators
// LiveSettingsScreen uses for its own cubit.
//
// This test proves the ROUTE builds without throwing, wrapped exactly as the
// fix wraps it — mirroring the DI-free harness style established by
// `back_nav_offer_composer_test.dart` ("proves the contract WITHOUT the
// per-screen DI/timer/network cost"): fakes stand in for the DI-resolved
// production collaborators so this carries no GetIt/network setup cost.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/settings_fakes.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  // A router that mounts the REAL `ProfileEditScreen` at `/settings/profile`,
  // wrapped exactly as the fixed `app_router.dart` wraps it: a
  // `BlocProvider<SettingsCubit>` scoped to just this route, one level above
  // the screen. The parent `/settings` stub mirrors only the route SHAPE
  // (name + nested path) that `settings_screen.dart` navigates against —
  // its body is irrelevant to this regression.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('SETTINGS-LIST'))),
            routes: [
              GoRoute(
                path: 'profile',
                name: 'settings-profile',
                builder: (context, state) => BlocProvider<SettingsCubit>(
                  create: (_) => SettingsCubit(
                    profileRepository: InMemoryProfileRepository(),
                    accountService: const FakeAccountService(),
                  )..load(),
                  child: const ProfileEditScreen(),
                ),
              ),
            ],
          ),
        ],
      );

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'direct deep-land on /settings/profile builds ProfileEditScreen '
    '(no ProviderNotFoundException<SettingsCubit>)',
    (tester) async {
      final router = await pump(tester);

      router.go('/settings/profile');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileEditScreen), findsOneWidget);
    },
  );

  testWidgets(
    'in-app nav — push named settings-profile from the settings list — '
    'builds ProfileEditScreen (no ProviderNotFoundException<SettingsCubit>)',
    (tester) async {
      final router = await pump(tester);
      expect(find.text('SETTINGS-LIST'), findsOneWidget);

      router.pushNamed('settings-profile');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileEditScreen), findsOneWidget);
    },
  );
}
