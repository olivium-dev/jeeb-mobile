// Isolated native UI test — LiveSettingsScreen (settings route host).
//
// This host has NO injectable seam and NO widget test: it loads
// `GET /v1/users/me` through `sl<Dio>()` on mount. Under the isolated harness
// GetIt is unconfigured, so the load fails fast and the screen renders its own
// network-error fallback (the honest "empty fallback" this host degrades to
// without a gateway). We screenshot that fallback in English and Arabic — the
// loaded settings list requires a live Dio and is out of scope for an isolated
// per-screen shot.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/settings/presentation/screens/live_settings_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings: network-error fallback without a gateway (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const LiveSettingsScreen(),
      'settings__network-error',
    );
  });

  testWidgets('settings: network-error fallback (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const LiveSettingsScreen(),
      'settings__network-error-ar',
      locale: const Locale('ar'),
    );
  });
}
