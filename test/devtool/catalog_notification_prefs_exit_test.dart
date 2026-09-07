import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final standalone in [false, true]) {
      for (final wrapper in [false, true]) {
        testWidgets(
          'notification preferences unauthorized exit ${locale.languageCode} standalone=$standalone wrapper=$wrapper',
          (tester) async {
            useReduceMotion(tester);
            final entry = kScreenCatalog.singleWhere(
              (e) => wrapper
                  ? e.feature == 'settings' &&
                        e.screen == 'NotificationPreferencesScreen'
                  : e.feature == 'notification_prefs',
            );
            final state = entry.states.singleWhere(
              (s) =>
                  s.label ==
                  (wrapper ? 'Unauthorized' : 'Unauthorized — safe back exit'),
            );
            final router = GoRouter(
              initialLocation: standalone ? '/prefs' : '/base/prefs',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      const Scaffold(body: Text('HOME_DESTINATION')),
                ),
                GoRoute(
                  path: '/prefs',
                  builder: (context, _) => state.builder(context),
                ),
                GoRoute(
                  path: '/base',
                  builder: (_, _) =>
                      const Scaffold(body: Text('PARENT_DESTINATION')),
                  routes: [
                    GoRoute(
                      path: 'prefs',
                      builder: (context, _) => state.builder(context),
                    ),
                  ],
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              MaterialApp.router(
                theme: AppTheme.midnight(),
                routerConfig: router,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  SyncAppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              ),
            );
            await tester.pumpAndSettle();
            final exit = find.bySemanticsIdentifier(
              'notif_prefs_load_exit_cta',
            );
            expect(exit, findsOneWidget);
            expect(
              find.bySemanticsIdentifier('notif_prefs_retry_cta'),
              findsNothing,
            );
            final cubit = tester.element(exit).read<NotificationPrefsCubit>();
            expect(cubit.state, isA<NotificationPrefsError>());
            final error = cubit.state as NotificationPrefsError;
            expect(error.failure, NotificationPrefsFailureView.unauthorized);
            expect(error.appFailure, isA<UnauthorizedFailure>());
            await tester.tap(exit);
            await tester.pumpAndSettle();
            expect(
              find.text(standalone ? 'HOME_DESTINATION' : 'PARENT_DESTINATION'),
              findsOneWidget,
            );
            expect(exit, findsNothing);
            expect(cubit.isClosed, isTrue);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
