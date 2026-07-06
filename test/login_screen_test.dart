import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/features/auth/presentation/login_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// The LoginScreen wraps its body in a [RootAwareBackScope] (a
/// [BackButtonListener]) which reads `Router.of(context)` at build — so the test
/// harness MUST provide a Router ancestor (MaterialApp.router + GoRouter), not a
/// plain `MaterialApp(home:)`. Mirrors `saved_locations_screen_test.dart`.
GoRouter _loginRouter() => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const LoginScreen(),
        ),
        // Target for the login screen's `goNamed('biometric-lock')` affordance.
        GoRoute(
          path: '/lock',
          name: 'biometric-lock',
          builder: (_, _) => const SizedBox.shrink(),
        ),
      ],
      errorBuilder: (_, _) => const LoginScreen(),
    );

Widget _wrapLogin(GoRouter router, {Locale locale = const Locale('en')}) =>
    MaterialApp.router(
      theme: ThemeData.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );

void main() {
  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
      'Dev Tool feature #1: super-login is NOT mounted on the login screen '
      '(it lives only in the Jeeber Dev Tool)', (tester) async {
    await tester.pumpWidget(_wrapLogin(_loginRouter()));
    await tester.pump();

    // The relocated super-login entry points were removed from the app; the
    // roster/picker/sheet now live exclusively behind the Jeeber Dev Tool.
    expect(find.byKey(const Key('login.superLogin')), findsNothing);
    expect(find.byKey(const Key('login.superLoginPlus')), findsNothing);
    expect(find.bySemanticsIdentifier('_super_login_link'), findsNothing);
    expect(
      find.bySemanticsIdentifier('super_login_plus_button'),
      findsNothing,
    );
  });
}
