// Isolated native UI test — RequestSummaryUnavailableScreen (graceful fallback
// for `/request-summary` reached without a RequestDraft, e.g. a cold deep-link).
// Fully static: an OMDSAppBar + an OmdsErrorState off localized copy, no
// seam/cubit/DI. Pumped directly. Captures the fallback en + ar.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_unavailable_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('request-summary-unavailable: fallback (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RequestSummaryUnavailableScreen(),
      'request-summary-unavailable__default',
    );
  });

  testWidgets('request-summary-unavailable: fallback (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const RequestSummaryUnavailableScreen(),
      'request-summary-unavailable__default-ar',
      locale: const Locale('ar'),
    );
  });
}
