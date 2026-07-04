// Widget tests for PasswordSecurityScreen (JM-061).
//
// Asserts the exact Semantics(identifier:) contract from 30_BACKLOG JM-061 +
// 67_W34_TEST_PLAN §JM-061 is present, the mismatch/strength validation stays on
// screen, the social-only entry routes to set-password (?mode=in-app-social,
// D90), and `password_back` → customer-profile. Maestro keys on identifiers
// (CTO brief §6.6), so these assert on `find.bySemanticsIdentifier`.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _delegate = SyncAppLocalizationsDelegate();

Widget _host({bool hasPassword = true}) {
  final router = GoRouter(
    initialLocation: '/settings/password',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings/password',
        name: 'password-security',
        builder: (_, _) => PasswordSecurityScreen(hasPassword: hasPassword),
      ),
      // The set-password target (JM-022). Renders setpw_new_field so the
      // password_set_entry → setpw_new_field nav assertion holds.
      GoRoute(
        path: '/set-password',
        name: 'set-password',
        builder: (_, state) => Scaffold(
          body: Semantics(
            identifier: 'setpw_new_field',
            child: Text('setpw-${state.uri.queryParameters['mode']}'),
          ),
        ),
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
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

Finder _field(String id) => find.descendant(
      of: find.bySemanticsIdentifier(id),
      matching: find.byType(EditableText),
    );

void main() {
  testWidgets('exposes the full JM-061 id contract (password account)',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('password_security_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_current_field'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_new_field'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_confirm_field'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('password_new_visibility_toggle'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('password_confirm_visibility_toggle'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('password_submit_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_set_entry'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_back'), findsOneWidget);
  });

  testWidgets('mismatched new/confirm → password_mismatch_error, stays on screen',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.enterText(_field('password_current_field'), 'OldPassword1');
    await tester.enterText(_field('password_new_field'), 'NewPassword2');
    await tester.enterText(_field('password_confirm_field'), 'NewPassword3');
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('password_submit_cta'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('password_mismatch_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_strength_error'), findsNothing);
    // Validation stays on screen — did NOT navigate away.
    expect(find.bySemanticsIdentifier('password_security_root'), findsOneWidget);
    expect(find.text('customer-profile-host'), findsNothing);
  });

  testWidgets('weak new password → password_strength_error', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.enterText(_field('password_current_field'), 'OldPassword1');
    await tester.enterText(_field('password_new_field'), 'weak');
    await tester.enterText(_field('password_confirm_field'), 'weak');
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('password_submit_cta'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('password_strength_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_mismatch_error'), findsNothing);
  });

  testWidgets(
      'B-33: a valid change does NOT fake success — it stays on screen and '
      'shows the honest "not available" notice (no navigation)', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.enterText(_field('password_current_field'), 'OldPassword1');
    await tester.enterText(_field('password_new_field'), 'NewPassword2');
    await tester.enterText(_field('password_confirm_field'), 'NewPassword2');
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('password_submit_cta'));
    await tester.pumpAndSettle();

    // NO false success: the screen must NOT navigate back to the profile as if
    // the password had changed (the pre-B-33 defect).
    expect(find.text('customer-profile-host'), findsNothing);
    expect(find.bySemanticsIdentifier('password_security_root'), findsOneWidget);
    // The honest notice is surfaced.
    expect(
      find.text("Changing your password isn't available yet. Nothing was saved."),
      findsOneWidget,
    );
  });

  testWidgets('password_set_entry → set-password (?mode=in-app-social, D90)',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('password_set_entry'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('setpw_new_field'), findsOneWidget);
    expect(find.text('setpw-in-app-social'), findsOneWidget);
  });

  testWidgets('eye toggle reveals the new-password field', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    EditableText newField() => tester.widget<EditableText>(_field('password_new_field'));
    expect(newField().obscureText, isTrue);

    await tester.tap(find.bySemanticsIdentifier('password_new_visibility_toggle'));
    await tester.pumpAndSettle();

    expect(newField().obscureText, isFalse);
  });

  testWidgets('social-only variant (hasPassword=false) hides the change form',
      (tester) async {
    await tester.pumpWidget(_host(hasPassword: false));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('password_set_entry'), findsOneWidget);
    expect(find.bySemanticsIdentifier('password_current_field'), findsNothing);
    expect(find.bySemanticsIdentifier('password_new_field'), findsNothing);
    expect(find.bySemanticsIdentifier('password_submit_cta'), findsNothing);
  });
}
