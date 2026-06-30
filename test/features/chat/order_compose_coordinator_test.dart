/// P0 #3 — order-create wiring.
///
/// Locks the fix for the dead-end where the order-chat compose→send path
/// broadcast the literal `new` sentinel and routed to `/v1/requests/new` (404).
/// The coordinator must CREATE a real request (POST /v1/requests) from the
/// composed first message, broadcast the SERVER-MINTED id, and NEVER forward
/// the `new` sentinel.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/order_compose_coordinator.dart';
import 'package:jeeb_mobile/features/chat/domain/order_broadcast_service.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

import '../../support/fake_request_submission_service.dart';

/// Records every broadcast call; optionally throws to exercise the soft-fail.
class _FakeBroadcastService implements OrderBroadcastService {
  _FakeBroadcastService({this.throwFailure = false});

  final bool throwFailure;
  final List<String> conversationIds = [];
  final List<String> requestIds = [];
  int calls = 0;

  @override
  Future<OrderBroadcastResult> broadcast({
    required String conversationId,
    required String requestId,
    String tier = '',
  }) async {
    calls++;
    conversationIds.add(conversationId);
    requestIds.add(requestId);
    if (throwFailure) {
      throw const OrderBroadcastException(OrderBroadcastFailure.network);
    }
    return OrderBroadcastResult(requestId: requestId, notifiedCount: 3);
  }
}

void main() {
  group('OrderComposeCoordinator — compose → create → broadcast (P0 #3)', () {
    test('creates a real request from the first message when id is the `new` '
        'sentinel, then broadcasts the SERVER-MINTED id (never `new`)',
        () async {
      final submission =
          FakeRequestSubmissionService(requestId: 'req-real-abc123');
      final broadcast = _FakeBroadcastService();
      final coordinator = OrderComposeCoordinator(
        submission: submission,
        broadcast: broadcast,
      );

      final id = await coordinator.createAndBroadcast(
        existingRequestId: OrderComposeCoordinator.composeSentinel, // 'new'
        firstMessage: 'Deliver a parcel from Hamra to Verdun',
      );

      // A real request was created from the composed message.
      expect(submission.submitCount, 1);
      expect(
        submission.lastDraft?.description,
        'Deliver a parcel from Hamra to Verdun',
      );
      // The REAL id is returned and broadcast — never the `new` sentinel.
      expect(id, 'req-real-abc123');
      expect(id, isNot(OrderComposeCoordinator.composeSentinel));
      expect(broadcast.calls, 1);
      expect(broadcast.requestIds.single, 'req-real-abc123');
      expect(broadcast.conversationIds.single, 'req-real-abc123');
      expect(broadcast.requestIds, isNot(contains('new')));
    });

    test('creates a request when the id is empty', () async {
      final submission = FakeRequestSubmissionService(requestId: 'req-empty-1');
      final broadcast = _FakeBroadcastService();
      final coordinator = OrderComposeCoordinator(
        submission: submission,
        broadcast: broadcast,
      );

      final id = await coordinator.createAndBroadcast(
        existingRequestId: '',
        firstMessage: 'Need a quick delivery',
      );

      expect(submission.submitCount, 1);
      expect(id, 'req-empty-1');
      expect(broadcast.requestIds.single, 'req-empty-1');
    });

    test('falls back to a non-empty description when the first message is blank',
        () async {
      final submission = FakeRequestSubmissionService(requestId: 'req-blank-1');
      final coordinator = OrderComposeCoordinator(
        submission: submission,
        broadcast: _FakeBroadcastService(),
      );

      await coordinator.createAndBroadcast(
        existingRequestId: 'new',
        firstMessage: '   ',
      );

      // The create-leg's only required field must never be empty.
      expect(submission.lastDraft?.description, isNotEmpty);
    });

    test('reuses an existing REAL request id without creating', () async {
      final submission = FakeRequestSubmissionService();
      final broadcast = _FakeBroadcastService();
      final coordinator = OrderComposeCoordinator(
        submission: submission,
        broadcast: broadcast,
      );

      final id = await coordinator.createAndBroadcast(
        existingRequestId: 'req-already-real-999',
        firstMessage: 'whatever',
      );

      expect(submission.submitCount, 0); // no create — already have a real id
      expect(id, 'req-already-real-999');
      expect(broadcast.requestIds.single, 'req-already-real-999');
    });

    test('returns null and does NOT broadcast when create fails', () async {
      final submission = FakeRequestSubmissionService(
        error: const RequestSubmissionException(
          RequestSubmissionFailure.server,
        ),
      );
      final broadcast = _FakeBroadcastService();
      final coordinator = OrderComposeCoordinator(
        submission: submission,
        broadcast: broadcast,
      );

      final id = await coordinator.createAndBroadcast(
        existingRequestId: 'new',
        firstMessage: 'Deliver now',
      );

      // No real request → never route, never broadcast the dead `new` id.
      expect(id, isNull);
      expect(broadcast.calls, 0);
    });

    test('soft-fails on a broadcast error but still returns the real id',
        () async {
      final submission =
          FakeRequestSubmissionService(requestId: 'req-soft-1');
      final broadcast = _FakeBroadcastService(throwFailure: true);
      final coordinator = OrderComposeCoordinator(
        submission: submission,
        broadcast: broadcast,
      );

      final id = await coordinator.createAndBroadcast(
        existingRequestId: 'new',
        firstMessage: 'Deliver despite a flaky matcher',
      );

      expect(id, 'req-soft-1'); // request is created/pending regardless
      expect(broadcast.calls, 1);
    });
  });
}
