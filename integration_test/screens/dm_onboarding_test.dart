// Isolated native UI test — jeeber-onboarding (DmOnboardingScreen, JM-037/038).
// The three-step wizard (photo → address → service-area) shares one cubit; the
// screen exposes a `cubit` seam + an `initialStep`, so — mirroring
// test/dm_onboarding_screen_test.dart — we seed a DmOnboardingCubit over the
// StubPhotoPickerService + in-repo FakeDmOnboardingGateway and land directly on
// each step. No GoRouter is needed at rest (the KYC hand-off only fires on
// coverage-ready), and the service-area map is the deterministic placeholder
// pin — no GoogleMap, no pending timers.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../support/screen_harness.dart';

DmOnboardingCubit _cubit(DmOnboardingStep step) => DmOnboardingCubit(
      pickerService: StubPhotoPickerService(),
      gateway: FakeDmOnboardingGateway(),
      initialStep: step,
    );

Widget _screen(DmOnboardingCubit cubit) => DmOnboardingScreen(cubit: cubit);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jeeber-onboarding: photo step (en)', (tester) async {
    final cubit = _cubit(DmOnboardingStep.photo);
    addTearDown(cubit.close);
    await pumpAndShoot(tester, binding, _screen(cubit), 'jeeber-onboarding__photo');
  });

  testWidgets('jeeber-onboarding: address step (en)', (tester) async {
    final cubit = _cubit(DmOnboardingStep.address);
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'jeeber-onboarding__address',
    );
  });

  testWidgets('jeeber-onboarding: service-area step (en)', (tester) async {
    final cubit = _cubit(DmOnboardingStep.serviceArea);
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'jeeber-onboarding__service-area',
    );
  });

  testWidgets('jeeber-onboarding: service-area step (ar)', (tester) async {
    final cubit = _cubit(DmOnboardingStep.serviceArea);
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'jeeber-onboarding__service-area-ar',
      locale: const Locale('ar'),
    );
  });
}
