// Designed states for `NoOfferTimeoutScreen` (JM-026 waiting / no-coverage) —
// ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_06_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/no_offer_timeout/presentation/
//     no_offer_timeout_screen.dart                      the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's five states were hand-built inside the entry file (a private
// `_staticWaitingCubit`, a private `_waitingPreview` host, and
// `FakeWaitingRepository` seeded with `DateTime.now()`). They moved here whole
// when the screen got a preview section, because two copies of the same
// "designed state" drift and the catalog is the one a designer signs off
// against.
//
// One thing changed in the move, and it is the reason the countdown is now
// reviewable rather than merely renderable: **the clock is frozen** ([clock]).
// The screen's countdown is derived from the snapshot's ANCHOR PAIR
// (`receivedAt` + `remainingAtReceipt`) measured against the cubit's injected
// `now`. The catalog stamped `receivedAt: DateTime.now()` and let the cubit
// default to the real `DateTime.now`, so the two instants differed by however
// long the fake's `Future` took to resolve and a 4:30 window rendered `4:29`
// about as often as `4:30`. Every seed below anchors on [clock] and
// [inertCubit] pins the cubit's `now` to the same instant, so `4:30 left to
// find a Jeeber` is exactly that string — in the canvas, in a render test, and
// on a designer's device.
//
// NOTHING here touches the network. Every repository answers from a canned
// snapshot, throws, or never completes, and [inertCubit] hands the cubit two
// EMPTY streams in place of its push-refresh bus and its 1 s countdown ticker —
// so no fixture can arm a timer or a subscription either. That second
// replacement is load-bearing: `clockTicks` defaults to a
// `Stream.periodic(1s)`, and a subscription to it is a pending timer that fails
// every widget test that mounts this screen. The `CatalogNetworkGuard` both
// hosts install is a net, not the plan.
//
// The five catalog states are the first five factories below. The rest are
// states the catalog does not name and that break: the cold read in flight, the
// server-owned terminal outcome, the honest no-countdown row (P7), the
// zero-notified broadcast that BUG-4 used to mislabel, and the layout ceiling.

import 'dart:async';

import '../../../features/no_offer_timeout/application/waiting_cubit.dart';
import '../../../features/no_offer_timeout/data/fake_waiting_repository.dart';
import '../../../features/no_offer_timeout/domain/waiting_repository.dart';
import '../../../features/no_offer_timeout/domain/waiting_request.dart';

/// A read that never resolves, freezing the screen on its loading body for as
/// long as the host is open.
///
/// The shipped [FakeWaitingRepository] cannot express this — it answers
/// immediately or throws — and the loading body is the one surface a customer
/// on a slow connection stares at longest. A [Completer] that is never
/// completed holds no timer and no subscription; it simply never settles.
class StalledWaitingRepository implements WaitingRepository {
  StalledWaitingRepository();

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) =>
      Completer<WaitingRequest>().future;

  @override
  Future<WaitingRequest> fetchRequest(String requestId) =>
      Completer<WaitingRequest>().future;

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) =>
      Completer<int>().future;
}

/// The designed states of `NoOfferTimeoutScreen`, as repositories plus the
/// cubit factory that keeps them inert.
///
/// The screen takes a REPOSITORY, not a state — it builds its own
/// [WaitingCubit] and calls `load()` at mount — so a state is described here by
/// what the repository answers, and the real two-phase cold-load path runs in
/// the catalog and in the canvas exactly as it does in production.
class NoOfferTimeoutScreenPreviewFixtures {
  const NoOfferTimeoutScreenPreviewFixtures._();

  /// The request every state hangs off.
  static const String requestId = 'REQ-WAIT-001';

  /// Frozen "now" for every anchor pair AND for the cubit's own clock, so the
  /// countdown renders an exact, pinnable string.
  static final DateTime clock = DateTime.utc(2026, 6, 18, 9);

  /// The cubit the screen would build for itself, with its two live streams
  /// replaced by empty ones and its clock pinned to [clock].
  ///
  /// All three substitutions matter. `refreshSignals` is the b02 wave-C
  /// push→refetch bus, which in a preview would resolve out of an unbuilt DI
  /// graph; `clockTicks` defaults to a `Stream.periodic(1s)` whose subscription
  /// is a PENDING TIMER; and `now` is what makes `remaining` equal
  /// `remainingAtReceipt` exactly rather than a few milliseconds less.
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
  ///
  /// [remaining] is the SERVER-relative time left at receipt, not a deadline:
  /// `null` means the server says no countdown applies to this row, which the
  /// screen must render as copy rather than as a fabricated `0:00` (P7).
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
  /// only signal allowed to raise the softened no-coverage variant.
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
  /// payload, so the screen stops and says so in its OWN copy — a QA run must
  /// report a backend contract break, never "check your connection".
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
  ///
  /// `WaitingCubit.load` returns early on a terminal phase — no streams are
  /// attached, no countdown runs — and the screen replaces the whole waiting
  /// surface with an exit. There is deliberately no retry, re-target or cancel
  /// here: this request has left the waiting flow.
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
  ///
  /// `remainingAtReceipt: null` is the server saying this row has no offer-wait
  /// window, NOT a missing field (a live row without one throws
  /// [WaitingFailure.contractViolation] in the repository and never reaches the
  /// screen). The countdown node stays mounted, because Maestro flows resolve
  /// it, and says so in words instead of rendering a fabricated `0:00`.
  static WaitingRepository noCountdown() => FakeWaitingRepository(
        seed: snapshot(
          notifiedCount: 12,
          remaining: null,
          displayId: 'ORD-5004',
          title: 'Documents from the notary',
        ),
      );

  /// BUG-4 / JM-026 false-no-coverage, seeded so the regression is visible.
  ///
  /// `notifiedCount` is informational and effectively ALWAYS zero in
  /// production — jeebers discover requests by pulling
  /// `GET /v1/jeebers/me/feed`, and the gateway populates no push-notify
  /// counter — so a screen that gated its no-coverage state on it told every
  /// waiting customer "No Jeebers nearby yet" while the broadcast was healthy.
  /// With the window still running this must render the neutral reassurance
  /// line and NOT the no-coverage block.
  static WaitingRepository zeroNotifiedStillCounting() => FakeWaitingRepository(
        seed: snapshot(
          remaining: const Duration(minutes: 3),
          displayId: 'ORD-5005',
          title: 'One box of baklava from Hallab',
        ),
      );

  /// The layout ceiling: the longest plausible request echo above the longest
  /// countdown this screen can emit.
  ///
  /// The window is the 24 h `TierExpiryWindowResolver.SafeExpiryWindow` the
  /// gateway falls back to when a request's tier does not resolve — the input
  /// that printed `1433:18 left to find a Jeeber` on real hardware before
  /// `CountdownFormat` promoted the hours field, and which
  /// `test/features/no_offer_timeout/waiting_countdown_hours_test.dart` pins.
  /// The title is a customer-typed paragraph, which the echo card renders in
  /// FULL with no `maxLines` cap.
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
