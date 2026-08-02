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
