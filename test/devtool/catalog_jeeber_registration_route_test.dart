import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

void main() {
  for (final locale in kFailureLocales) {
    testWidgets(
      '404 catalog offers actual registration route: ${locale.languageCode}',
      (tester) async {
        useReduceMotion(tester);
        final state = kScreenCatalog
            .singleWhere((e) => e.feature == 'jeeber_home')
            .states
            .singleWhere(
              (s) => s.label == 'Not registered — availability answered 404',
            );
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, _) => state.builder(context)),
            GoRoute(
              path: '/register',
              name: 'jeeber-onboarding',
              builder: (_, _) =>
                  const Scaffold(body: Text('REGISTRATION_ROUTE')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.midnight(),
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
        await pumpPastFakeLatency(tester);
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(JeeberHomeScreen));
        final cubit = context.read<AvailabilityCubit>();
        addTearDown(cubit.close);
        expect(
          find.bySemanticsIdentifier('jeeber_home_not_registered_state'),
          findsOneWidget,
        );
        final cta = find.bySemanticsIdentifier('jeeber_home_register_cta');
        expect(cta, findsOneWidget);
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.text('REGISTRATION_ROUTE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
