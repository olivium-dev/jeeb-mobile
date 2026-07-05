// Isolated native UI test — ProfileUnavailableScreen (release-safe fallback for
// a `/profile/*` route reached without its typed view-data). Fully static: an
// OMDSAppBar + an OmdsErrorState off localized copy, no seam/cubit/DI. Pumped
// directly. Captures the fallback en + ar.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/core/router/profile_unavailable_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile-unavailable: fallback (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const ProfileUnavailableScreen(),
      'profile-unavailable__default',
    );
  });

  testWidgets('profile-unavailable: fallback (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const ProfileUnavailableScreen(),
      'profile-unavailable__default-ar',
      locale: const Locale('ar'),
    );
  });
}
