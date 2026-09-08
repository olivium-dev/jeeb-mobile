// EP-19: the error empty-state had NO CTA, so the screen was a dead end whose
// only exit was the back circle — which is dead at the stack root.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/router/profile_unavailable_screen.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

Widget _harness({
  required bool parentOnStack,
  Locale locale = const Locale('en'),
}) {
  final GoRouter router = GoRouter(
    initialLocation: parentOnStack ? '/' : '/profile/customer',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
        routes: <RouteBase>[
          GoRoute(
            path: 'profile/customer',
            builder: (_, _) => const ProfileUnavailableScreen(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the exit CTA renders on the frozen '
        'block', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(parentOnStack: false, locale: locale),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('profile_unavailable_note'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('profile_unavailable_exit_cta'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile_unavailable_state')), findsOneWidget);
    });
  }

  testWidgets('at the stack root the CTA goes home rather than popping',
      (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(_harness(parentOnStack: false));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.bySemanticsIdentifier('profile_unavailable_exit_cta'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsIdentifier('profile_unavailable_exit_cta'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileUnavailableScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });
}
