// Isolated native UI test — RequestTypeScreen (request-type-selection, JM-024).
// The screen owns its BlocProvider and builds a TierSelectionCubit from the
// injected `repository` seam, so passing the in-memory FakeTierRepository avoids
// GetIt/network — the cubit pre-selects the recommended Flash tier on load, so
// the Continue CTA is enabled on first paint. The load is a plain Future (no
// timers). Continue/Change-location touch `sl<>()` only on tap, so the plain
// MaterialApp harness is enough. The error branch falls back to the same cached
// catalog, so only the loaded state is reachable — captured in en + Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('request-type: tier catalog loaded (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RequestTypeScreen(repository: FakeTierRepository()),
      'request-type__loaded',
    );
  });

  testWidgets('request-type: tier catalog loaded (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RequestTypeScreen(repository: FakeTierRepository()),
      'request-type__ar',
      locale: const Locale('ar'),
    );
  });
}
