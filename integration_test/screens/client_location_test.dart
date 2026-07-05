// Isolated native UI test — client-location (ClientLocationScreen, JM-024). The
// screen self-provides its LocationSelectCubit with a `repository` + `userId`
// override, so we hand it the in-repo FakeLocationSelectRepository (Home +
// Office saved addresses) and an explicit userId — which takes the direct
// BlocProvider branch (no AuthTokenStore FutureBuilder). It renders the
// create-flow: "What do you need?" field, current-location + saved-address
// options, new-location CTA, and the recipient-phone field. No GoogleMap; the
// cubit's saved-address load settles with no pending timers.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';

import '../support/screen_harness.dart';

Widget _screen() => const ClientLocationScreen(
      repository: FakeLocationSelectRepository(),
      userId: 'user-client-001',
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client-location: loaded create step (en)', (tester) async {
    await pumpAndShoot(tester, binding, _screen(), 'client-location__loaded');
  });

  testWidgets('client-location: loaded create step (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'client-location__loaded-ar',
      locale: const Locale('ar'),
    );
  });
}
