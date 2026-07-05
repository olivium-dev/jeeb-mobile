// Isolated native UI test — KycRejectedScreen (kyc-rejected, JM-043). The
// screen owns its BlocProvider + resolves the KycGateway seam; when a gateway
// is passed no DI is needed. We use the in-memory FakeKycGateway: its default
// fetchStatus() returns a non-rejected stored submission (generic FINAL copy),
// while an `initial:` rejected submission surfaces the structured reason notice.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';

import '../support/screen_harness.dart';

KycRejectedScreen _rejectedWithReason(KycRejectionReason reason) =>
    KycRejectedScreen(
      gateway: FakeKycGateway(
        initial: KycSubmission(
          status: KycStatus.rejected,
          rejectionReason: reason,
          submittedAt: DateTime.utc(2026, 7, 1, 10),
        ),
      ),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kyc-rejected: generic final copy, no structured reason (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      KycRejectedScreen(gateway: FakeKycGateway()),
      'kyc-rejected__generic',
    );
  });

  testWidgets('kyc-rejected: with structured reason (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _rejectedWithReason(KycRejectionReason.idUnreadable),
      'kyc-rejected__reason',
    );
  });

  testWidgets('kyc-rejected: with structured reason (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _rejectedWithReason(KycRejectionReason.selfieMismatch),
      'kyc-rejected__reason-ar',
      locale: const Locale('ar'),
    );
  });
}
