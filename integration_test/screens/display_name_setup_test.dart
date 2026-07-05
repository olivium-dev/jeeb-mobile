// Isolated native UI test — DisplayNameSetupScreen (profile-name lane, the
// post-OTP display-name onboarding step). The screen self-provides its
// DisplayNameCubit and takes an optional `repository` seam; we inject an
// in-line no-op repository (as test/features/profile_name/
// display_name_setup_screen_test.dart does) so the idle form renders without
// GetIt/Dio. onDone is a no-op — nothing resolves at build. Captures the idle
// name-entry form en + ar (RTL).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';
import 'package:jeeb_mobile/features/profile_name/presentation/display_name_setup_screen.dart';

import '../support/screen_harness.dart';

/// No-op repository so the self-provided cubit constructs without DI/network.
class _FakeDisplayNameRepository implements DisplayNameRepository {
  @override
  Future<void> submitDisplayName(String name) async {}
}

Widget _screen() => DisplayNameSetupScreen(
      onDone: () {},
      repository: _FakeDisplayNameRepository(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('display-name-setup: idle form (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'display-name-setup__idle',
    );
  });

  testWidgets('display-name-setup: idle form (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'display-name-setup__idle-ar',
      locale: const Locale('ar'),
    );
  });
}
