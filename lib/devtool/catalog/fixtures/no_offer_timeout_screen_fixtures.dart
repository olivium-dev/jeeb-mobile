// Designed states for `NoOfferTimeoutScreen` (JM-026 waiting / no-coverage) —

import 'dart:async';

import '../../../features/no_offer_timeout/application/waiting_cubit.dart';
import '../../../features/no_offer_timeout/data/fake_waiting_repository.dart';
import '../../../features/no_offer_timeout/domain/waiting_repository.dart';
import '../../../features/no_offer_timeout/domain/waiting_request.dart';

/// A read that never resolves, freezing the screen on its loading body for as
/// long as the host is open.
/// The shipped [FakeWaitingRepository] cannot express this — it answers
class StalledWaitingRepository implements WaitingRepository {
  StalledWaitingRepository();

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) =>
      Completer<WaitingRequest>().future;

  @override
  Future<WaitingRequest> fetchRequest(String requestId) =>
      Completer<WaitingRequest>().future;

  @override
  Future<int?> fetchOfferCount(String requestId) => Completer<int?>().future;
}

/// UX-34: the live offer probe cannot be read, so the count is UNKNOWN and the
/// screen says so instead of printing a fabricated number.
class OfferCountUnavailableWaitingRepository implements WaitingRepository {
  OfferCountUnavailableWaitingRepository(this.seed);

  final WaitingRequest seed;

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async =>
      seed.copyWith(offerCountIsProbed: false);

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => seed;

  @override
  Future<int?> fetchOfferCount(String requestId) async => null;
}

/// The designed states of `NoOfferTimeoutScreen`, as repositories plus the
/// cubit factory that keeps them inert.
/// The screen takes a REPOSITORY, not a state — it builds its own
class NoOfferTimeoutScreenPreviewFixtures {
  const NoOfferTimeoutScreenPreviewFixtures._();

  /// The request every state hangs off.
  static const String requestId = 'REQ-WAIT-001';

  /// Frozen "now" for every anchor pair AND for the cubit's own clock, so the
  /// countdown renders an exact, pinnable string.
  static final DateTime clock = DateTime.utc(2026, 6, 18, 9);

  /// The cubit the screen would build for itself, with its two live streams
  /// replaced by empty ones and its clock pinned to [clock].
  static WaitingCubit inertCubit(
    WaitingRepository repository,
    String requestId,
  ) {
    return WaitingCubit(
      repository: repository,
      requestId: requestId,
      now: () => clock,
      refreshSignals: const Stream<void>.empty(),
      clockTicks: const Stream<void>.empty(),
    );
  }

  /// One snapshot, anchored on [clock].
  /// [remaining] is the SERVER-relative time left at receipt, not a deadline:
  static WaitingRequest snapshot({
    WaitingRequestPhase phase = WaitingRequestPhase.broadcasting,
    int notifiedCount = 0,
    int offerCount = 0,
    Duration? remaining = const Duration(minutes: 4, seconds: 30),
    String? displayId = 'ORD-5001',
    String? tier = 'express',
    String? title,
  }) {
    return WaitingRequest(
      requestId: requestId,
      phase: phase,
      notifiedCount: notifiedCount,
      offerCount: offerCount,
      receivedAt: clock,
      remainingAtReceipt: remaining,
      displayId: displayId,
      tier: tier,
      title: title,
    );
  }

  // ─────────────────────── the five catalog states ────────────────────────

  /// Catalog "Broadcasting (counting down)": the request is fanning out, six
  /// Jeebers have been notified and 4:30 is left on the server-anchored window.
  static WaitingRepository broadcasting() => FakeWaitingRepository(
        seed: snapshot(
          notifiedCount: 6,
          remaining: const Duration(minutes: 4, seconds: 30),
          title: '2 grocery bags from Spinneys',
        ),
      );

  /// Catalog "Offers arrived": at least one bid is in, so the screen flips to
  /// the review-offers CTA (AC2) while the window keeps running.
  static WaitingRepository offersArrived() => FakeWaitingRepository(
        seed: snapshot(
          phase: WaitingRequestPhase.offersArrived,
          notifiedCount: 6,
          offerCount: 3,
          remaining: const Duration(minutes: 2),
          title: '2 grocery bags from Spinneys',
        ),
      );

  /// Catalog "No offers yet (window elapsed)": the broadcast window has fully
  /// elapsed with ZERO offers in — `remaining == Duration.zero` — which is the
  static WaitingRepository noOffersYet() => FakeWaitingRepository(
        seed: snapshot(
          remaining: Duration.zero,
          displayId: 'ORD-5002',
          tier: 'standard',
        ),
      );

  /// Catalog "Error": the cold read fails on the transport.
  static WaitingRepository failingLoad() => FakeWaitingRepository(
        failure: const WaitingException(WaitingFailure.network),
      );

  /// Catalog "Contract violation" (P7): the gateway answered 200 but omitted
  /// `offerDeadlineInSeconds` on a live row. Retrying re-reads the same broken
  static WaitingRepository contractViolation() => FakeWaitingRepository(
        failure: const WaitingException(
          WaitingFailure.contractViolation,
          'offerDeadlineInSeconds absent on a live broadcasting row',
        ),
      );

  // ──────────────────── states the catalog does not name ───────────────────

  /// The cold read in flight: `GET /v1/requests/{id}` has not answered yet.
  static WaitingRepository stalledLoad() => StalledWaitingRepository();

  /// The server-owned terminal outcome: the request expired before anyone bid.
  /// `WaitingCubit.load` returns early on a terminal phase — no streams are
  static WaitingRepository terminalExpired() => FakeWaitingRepository(
        seed: snapshot(
          phase: WaitingRequestPhase.expired,
          notifiedCount: 4,
          remaining: null,
          displayId: 'ORD-5003',
          title: 'Pharmacy run',
        ),
      );

  /// P7 — the honest "no countdown applies" row.
  /// `remainingAtReceipt: null` is the server saying this row has no offer-wait
  static WaitingRepository noCountdown() => FakeWaitingRepository(
        seed: snapshot(
          notifiedCount: 12,
          remaining: null,
          displayId: 'ORD-5004',
          title: 'Documents from the notary',
        ),
      );

  /// BUG-4 / JM-026 false-no-coverage, seeded so the regression is visible.
  /// `notifiedCount` is informational and effectively ALWAYS zero in
  static WaitingRepository zeroNotifiedStillCounting() => FakeWaitingRepository(
        seed: snapshot(
          remaining: const Duration(minutes: 3),
          displayId: 'ORD-5005',
          title: 'One box of baklava from Hallab',
        ),
      );

  /// The offer count could not be probed — `waiting_offer_count_unavailable`.
  static WaitingRepository countUnavailableRepository() =>
      OfferCountUnavailableWaitingRepository(
        snapshot(
          notifiedCount: 6,
          remaining: const Duration(minutes: 3),
          title: '2 grocery bags from Spinneys',
        ),
      );

  /// The layout ceiling: the longest plausible request echo above the longest
  /// countdown this screen can emit.
  static WaitingRepository longestContent() => FakeWaitingRepository(
        seed: snapshot(
          notifiedCount: 137,
          remaining: const Duration(hours: 23, minutes: 53, seconds: 18),
          displayId: 'ORD-500100137',
          tier: 'standard',
          title: 'Two sealed envelopes from the notary office on Bliss Street, '
              'then a 5 kg bag of cat litter and four bottles of sparkling '
              'water from the Spinneys downstairs — please ring the bell '
              'twice, the intercom on the third floor has been broken since '
              'March.',
        ),
      );
}
