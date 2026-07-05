// Isolated native UI test — ShellScreen (shell, '/'). The bottom-nav host that
// mounts the 5 additive tab surfaces (Requests, Delivery, Jeeber, Earnings,
// Profile) in an IndexedStack. Its role/badge reads are NULLABLE watches
// (`context.watch<RoleAvailabilityCubit?>()` / `BadgeCountCubit?>()`), so a bare
// harness with no app-level providers renders badge-less and lands on the
// Requests tab — exactly the shell chrome we want to capture. The individual
// tab bodies are validated by their own screen tests; this asserts the host
// scaffold + bottom bar composes and renders. Covers en + Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell: bottom-nav host, requests landing (en)', (tester) async {
    await pumpAndShoot(tester, binding, const ShellScreen(), 'shell__landing');
  });

  testWidgets('shell: bottom-nav host (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const ShellScreen(),
      'shell__ar',
      locale: const Locale('ar'),
    );
  });
}
