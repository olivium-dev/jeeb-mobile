import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

/// In-memory [WaitingRepository] used as a widget-test seam and a defensive DI
/// fallback (mirrors `FakeOffersRepository` / `FakeCancelRequestRepository`).
///
/// Production resolves [DioWaitingRepository] from DI; this fake is only wired
/// via the screen's constructor `repository:` parameter in tests, or as a
/// last-resort fallback if the DI batch for `WaitingRepository` has not landed
/// yet (so the screen renders a deterministic broadcasting state instead of
/// crashing). It returns a single seeded snapshot.
class FakeWaitingRepository implements WaitingRepository {
  FakeWaitingRepository({WaitingRequest? seed, this.failure}) : _seed = seed;

  final WaitingRequest? _seed;

  /// When set, [fetchWaiting] throws this instead of returning a snapshot.
  final WaitingException? failure;

  WaitingRequest _snapshot(String requestId) =>
      _seed ??
      WaitingRequest(
        requestId: requestId,
        phase: WaitingRequestPhase.broadcasting,
        notifiedCount: 4,
        offerCount: 0,
        // The live contract is NOT deadline-optional for a live row: the
        // gateway always ships `offerDeadlineInSeconds` while the offer-wait
        // window is open, so the fake seeds a real anchor pair rather than
        // leaving the cubit to invent one (it no longer can).
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
