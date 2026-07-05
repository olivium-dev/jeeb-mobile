// Isolated native UI test — OfferKycGateScreen (offer-kyc-gate, JM-044). The
// screen self-provides an OfferKycGateCubit from an injected `gateway` (or a
// FakeKycGateway fallback), so we inject a scripted gateway to drive the
// optional live status line. Covers the pending-status gate, the rejected-status
// gate, and the pending gate in Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';

import '../support/screen_harness.dart';

OfferKycGateScreen _screen(KycStatus status) => OfferKycGateScreen(
      gateway: FakeKycGateway(initial: KycSubmission(status: status)),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offer-kyc-gate: pending status line (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(KycStatus.pending),
      'offer-kyc-gate__pending',
    );
  });

  testWidgets('offer-kyc-gate: rejected status line (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(KycStatus.rejected),
      'offer-kyc-gate__rejected',
    );
  });

  testWidgets('offer-kyc-gate: pending status line (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(KycStatus.pending),
      'offer-kyc-gate__ar',
      locale: const Locale('ar'),
    );
  });
}
