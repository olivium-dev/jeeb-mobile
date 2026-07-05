// Isolated native UI test — PasswordSecurityScreen (password-security, JM-061).
// The screen self-provides its cubit (local-validation only, no network) — the
// default `PasswordSecurityCubit()` is fully deterministic, so no seam is
// injected. `hasPassword` gates the change-password form vs. the social-only
// "set a password" entry. Covers the change form (en), the social-only variant
// (en), and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('password-security: change-password form (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const PasswordSecurityScreen(),
      'password-security__idle',
    );
  });

  testWidgets('password-security: social-only entry, form hidden (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const PasswordSecurityScreen(hasPassword: false),
      'password-security__social-only',
    );
  });

  testWidgets('password-security: change-password form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const PasswordSecurityScreen(),
      'password-security__ar',
      locale: const Locale('ar'),
    );
  });
}
