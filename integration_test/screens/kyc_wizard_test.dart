// Isolated native UI test — KycWizardScreen (kyc-status, JM-040/042). The
// screen takes a `cubit` seam (KycWizardScreen(cubit:)) and hosts its own
// BlocProvider.value, so we drive the KycStatusView terminal states by seeding a
// KycWizardCubit over an in-memory FakeKycGateway (no DI/network), exactly as
// test/kyc_wizard_screen_test.dart does. onSubmitted is a no-op so no navigation
// is attempted under the harness's plain MaterialApp.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../support/screen_harness.dart';

Uint8List _bytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = 0x42;
  }
  return out;
}

KycWizardCubit _newCubit(KycGateway gateway) => KycWizardCubit(
      pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
      gateway: gateway,
    );

/// Seeds a submission through the gateway, then returns a fresh cubit that
/// re-enters the wizard via loadStatus() — landing on the KycStatusView for the
/// scripted terminal decision.
Future<KycWizardCubit> _terminalCubit(KycStatus decision,
    {KycRejectionReason? rejectionReason}) async {
  final shared = FakeKycGateway(
    decision: decision,
    rejectionReason: rejectionReason ?? KycRejectionReason.idUnreadable,
  );
  final seeder = _newCubit(shared);
  await seeder.loadSchema();
  await seeder.captureIdFront();
  await seeder.captureIdBack();
  await seeder.captureSelfie();
  seeder.setTosAccepted(true);
  await seeder.submit();
  await seeder.close();

  final reentry = _newCubit(shared)..loadStatus();
  return reentry;
}

Widget _host(KycWizardCubit cubit) =>
    KycWizardScreen(cubit: cubit, onSubmitted: (_) {});

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kyc-status: identity capture step (en)', (tester) async {
    final cubit = _newCubit(FakeKycGateway())..loadSchema();
    addTearDown(cubit.close);
    await pumpAndShoot(tester, binding, _host(cubit), 'kyc-status__identity');
  });

  testWidgets('kyc-status: approved terminal (en)', (tester) async {
    final cubit = await _terminalCubit(KycStatus.approved);
    addTearDown(cubit.close);
    await pumpAndShoot(tester, binding, _host(cubit), 'kyc-status__approved');
  });

  testWidgets('kyc-status: rejected terminal (ar)', (tester) async {
    final cubit = await _terminalCubit(
      KycStatus.rejected,
      rejectionReason: KycRejectionReason.selfieMismatch,
    );
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _host(cubit),
      'kyc-status__rejected-ar',
      locale: const Locale('ar'),
    );
  });
}
