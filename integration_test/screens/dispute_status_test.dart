// Isolated native UI test — DisputeStatusScreen (routed dispute-status).
// Pumped directly with a fake repository seam returning open / resolved.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';

import '../support/screen_harness.dart';

class _FakeDisputeRepo implements DisputeStatusRepository {
  const _FakeDisputeRepo(this._status);
  final DisputeStatus _status;
  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => _status;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dispute-status: open (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DisputeStatusScreen(
        disputeId: 'dispute-client-001-open',
        repository: _FakeDisputeRepo(
          DisputeStatus(
            id: 'dispute-client-001-open',
            state: DisputeState.open,
            orderRef: 'JB-1001',
            conversationRef: 'conv-journey-accepted',
            createdAt: '2026-07-01T10:00:00Z',
            evidence: DisputeEvidenceSummary(
              reason: 'Item arrived damaged',
              comment: 'The box was crushed on delivery.',
              photoCount: 2,
              hasVoice: true,
              hasChatSnapshot: true,
              chatMessageCount: 6,
              timelineCount: 3,
            ),
          ),
        ),
      ),
      'dispute-status__open',
    );
  });

  testWidgets('dispute-status: resolved refund (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const DisputeStatusScreen(
        disputeId: 'dispute-client-001-open',
        repository: _FakeDisputeRepo(
          DisputeStatus(
            id: 'dispute-client-001-open',
            state: DisputeState.resolved,
            outcome: DisputeOutcome.refund,
            resolution: 'refund_issued',
            note: 'Full refund issued to your wallet.',
            refundAmount: 25.0,
            currency: 'SAR',
            orderRef: 'JB-1001',
            createdAt: '2026-07-01T10:00:00Z',
            resolvedAt: '2026-07-03T14:00:00Z',
          ),
        ),
      ),
      'dispute-status__resolved-ar',
      locale: const Locale('ar'),
    );
  });
}
