// PS-01 / PS-02: the "not available yet" truth arrived only AFTER the user
// typed a valid password and submitted, and a SECOND identical `unavailable`
// emit was swallowed by Equatable so the listener never re-fired.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_cubit.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_state.dart';
import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _host({
  Locale locale = const Locale('en'),
  PasswordSecurityCubit Function()? cubitFactory,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/settings/password',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/password',
        name: 'password-security',
        builder: (_, _) => PasswordSecurityScreen(cubitFactory: cubitFactory),
      ),
      GoRoute(
        path: '/set-password',
        name: 'set-password',
        builder: (_, _) => const Scaffold(body: Text('setpw')),
      ),
      GoRoute(
        path: '/profile/customer',
        name: 'customer-profile',
        builder: (_, _) => const Scaffold(body: Text('customer-profile-host')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('the note is on the FIRST frame, before any typing ($tag)',
        (tester) async {
      await tester.pumpWidget(_host(locale: locale));
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('password_unavailable_note'),
        findsOneWidget,
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(PasswordSecurityScreen)),
      );
      expect(find.text(l10n.passwordChangeUnavailable), findsOneWidget);
    });
  }

  testWidgets('the submit CTA is disabled, never a lie', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final JeebCtaButton cta = tester.widget<JeebCtaButton>(
      find.descendant(
        of: find.bySemanticsIdentifier('password_submit_cta'),
        matching: find.byType(JeebCtaButton),
      ),
    );
    expect(cta.isEnabled, isFalse);
  });

  test('a second valid submit bumps the nonce so the listener re-fires',
      () async {
    final PasswordSecurityCubit cubit = PasswordSecurityCubit();
    final List<PasswordSecurityState> seen = <PasswordSecurityState>[];
    final sub = cubit.stream.listen(seen.add);

    void submit() => cubit.submit(
          current: 'OldPassword1',
          newPassword: 'NewPassword2',
          confirm: 'NewPassword2',
        );

    submit();
    submit();
    await Future<void>.delayed(Duration.zero);

    addTearDown(() async {
      await sub.cancel();
      await cubit.close();
    });

    final List<PasswordSecurityState> unavailable = seen
        .where((s) => s.status == PasswordSecurityStatus.unavailable)
        .toList();
    expect(unavailable.length, 2, reason: 'the second emit must not be eaten');
    expect(unavailable[1].unavailableNonce, unavailable[0].unavailableNonce + 1);
  });

  test('validation still wins over the unavailable notice', () async {
    final PasswordSecurityCubit cubit = PasswordSecurityCubit()
      ..submit(
        current: 'OldPassword1',
        newPassword: 'NewPassword2',
        confirm: 'Different3',
      );

    expect(cubit.state.status, PasswordSecurityStatus.failed);
    expect(cubit.state.hasMismatchError, isTrue);
    expect(cubit.state.unavailableNonce, 0);
    await cubit.close();
  });
}
