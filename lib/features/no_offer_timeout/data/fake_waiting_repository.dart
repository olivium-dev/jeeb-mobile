import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

class FakeWaitingRepository implements WaitingRepository {
  FakeWaitingRepository({WaitingRequest? seed, this.failure}) : _seed = seed;

  final WaitingRequest? _seed;

  final WaitingException? failure;

  WaitingRequest _snapshot(String requestId) =>
      _seed ??
      WaitingRequest(
        requestId: requestId,
        phase: WaitingRequestPhase.broadcasting,
        notifiedCount: 4,
        offerCount: 0,
        receivedAt: DateTime.now(),
        remainingAtReceipt: const Duration(minutes: 5),
        displayId: 'ORD-FAKE',
        tier: 'express',
        title: 'Waiting for Jeebers',
      );

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return _snapshot(requestId);
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return _snapshot(requestId);
  }

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) async =>
      _snapshot(requestId).offerCount;
}
