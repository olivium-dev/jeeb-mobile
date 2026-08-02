// Shared dev-only fixtures for `LiveTrackingScreen` (JM-032 `order-tracking`).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_06_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/live_tracking/presentation/live_tracking_screen.dart`.
//
// The catalog used to own a private `_StaticTrackingRepository`, a private
// `_FailingTrackingRepository`, two inline `DeliveryTrackingInfo` literals and a
// private `_liveTrackingPreview` cubit builder. They moved here whole when the
// screen got a preview section — two copies of the same "designed state" drift,
// and the catalog is the one a designer signs off against.
//
// ## The screen has exactly ONE seam, and it is ambient
//
// `LiveTrackingScreen` takes no `cubit:` or `repository:` override: it reads
// `LiveTrackingCubit` off the context (`BlocConsumer`), so BOTH surfaces have to
// mount a provider above it. `LiveTrackingCubit` in turn has no `seed:`
// constructor and `emit` is `@protected`, so a designed state is reached the way
// the app reaches it — through the cubit's own constructor read, over a local
// fake that answers however the state needs. Every fixture below is therefore a
// claim about a real transition, and if the cubit stops producing that state the
// fixture stops producing it too.
//
// ## Network-free by construction
//
// Every repository here answers from a `const` object, throws a typed
// [LiveTrackingException], or never completes. None builds a Dio client or
// touches GetIt, so neither dev surface depends on the `CatalogNetworkGuard` its
// host installs — that stays a net rather than the plan.
//
// Two more things are deliberately switched off in every fixture:
//
//  * `refreshSignals: const Stream<void>.empty()` — the push→refetch bus. With
//    no source the cubit reads ONCE, on construction, and arms a subscription
//    that can never fire, so a preview leaks no timer and no listener.
//  * no `positionChannel:` and no [LivePositionSource] on any repository here,
//    so `_readLivePosition` early-returns on its `repo is! LivePositionSource`
//    arm and no courier-position read is ever attempted. The map surface is
//    reviewed on its own previews (`tracking_map_surface.dart`), where the
//    freshness ladder is the subject.
//
// ## `stageTimestamps` is empty on purpose
//
// Nothing on this screen renders it — `OrderTrackingStepper` takes an index and
// an `atDoor` flag, and `DeliveryTrackingPanel` reads distance/ETA/deadline. The
// catalog's in-transit state used to come from `DemoLiveTrackingRepository`,
// whose timestamps are `DateTime.now()` offsets; carrying that into a fixture
// would have made every state a function of the wall clock for no visible gain.
// The field values that DO render are preserved verbatim from that repository.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';

/// Static repository serving one fixed snapshot: no network, no ticks, and no
/// [LivePositionSource] capability (so the cubit attempts no position read).
class LiveTrackingScreenStaticRepository implements LiveTrackingRepository {
  const LiveTrackingScreenStaticRepository(this.info);

  final DeliveryTrackingInfo info;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      info;
}

/// Repository that always fails with a typed kind — drives the screen's error
/// body, including the distinct 404 "Delivery not found" heading.
class LiveTrackingScreenFailingRepository implements LiveTrackingRepository {
  const LiveTrackingScreenFailingRepository(this.kind);

  final LiveTrackingErrorKind kind;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      throw LiveTrackingException(kind);
}

/// Repository whose read never answers — the ONLY way to hold the screen on
/// `LiveTrackingViewMode.loading` long enough to look at it.
///
/// The cubit starts in `loading` and leaves it on the first emit, so a fixture
/// that answered (even instantly) would be un-reviewable: the loading frame
/// exists but is never the settled one.
class LiveTrackingScreenPendingRepository implements LiveTrackingRepository {
  const LiveTrackingScreenPendingRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) =>
      Completer<DeliveryTrackingInfo>().future;
}

/// In-memory [HandoverCodeStore] — the local, accept-time source of the G4
/// hand-over code.
///
/// This is the ONLY way to put a code on this screen. The cubit deliberately
/// never reads `GET /otp` (that endpoint TRIGGERS AN SMS on the live gateway),
/// so a fixture with no store models a device that was reinstalled mid-delivery
/// and a fixture with one models the ordinary post-accept device.
class LiveTrackingScreenMemoryHandoverStore implements HandoverCodeStore {
  const LiveTrackingScreenMemoryHandoverStore(this.code);

  /// What [read] returns for every delivery id. Null models "this device never
  /// received the code".
  final String? code;

  @override
  Future<String?> read({required String deliveryId}) async => code;

  @override
  Future<void> save({required String deliveryId, required String code}) async {}

  @override
  Future<void> clear({required String deliveryId}) async {}
}

/// The designed states of `LiveTrackingScreen`, one builder each.
///
/// Every builder returns a FRESH cubit — both hosts rebuild on every open, and a
/// shared cubit would carry one reviewer's taps into the next state.
final class LiveTrackingScreenFixtures {
  const LiveTrackingScreenFixtures._();

  /// The delivery every fixture tracks. Both hosts pass this to the screen, so
  /// the id in the `/orders/{id}/otp` push route matches the row on screen.
  static const String deliveryId = 'DLV-990001';

  /// The G4 hand-over code as the accept response spells it: four digits, which
  /// is what `_HandoverCodeRow` letter-spaces and `OtpAtDoorCard` renders large.
  static const String handoverCode = '2144';

  /// The matched courier, in the PUBLIC in-flight slice the gateway is allowed
  /// to surface (no phone, no rating — blind-reveal holds until completion).
  static const JeeberSummary jeeber = JeeberSummary(
    displayName: 'Rami K.',
    vehicleLabel: 'Scooter',
  );

  // ── Designed snapshots ──────────────────────────────────────────────────

  /// Matched but nothing has moved yet: no courier assigned, no pinned summary.
  ///
  /// The genuinely EMPTY reading of the active layout — `hasSummary` is false
  /// (no price, no jeeber name) so the header is not mounted, `info.jeeber` is
  /// null so the courier card is not mounted, and the panel has neither a
  /// distance nor an ETA. What is left is the stepper, the map placeholder, the
  /// hand-over row and the two CTAs.
  static const DeliveryTrackingInfo orderedInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.ordered,
    stageTimestamps: <TrackingStage, DateTime>{},
    requestId: 'REQ-9001',
  );

  /// Picked up, courier assigned, summary complete — the reference reading.
  ///
  /// Every optional section of `_TrackingBody` is mounted at once: the pinned
  /// header, the 4-step stepper at step 2, the map surface, the courier card,
  /// the hand-over code row, the status panel and the action bar.
  static const DeliveryTrackingInfo pickedUpInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.picked,
    stageTimestamps: <TrackingStage, DateTime>{},
    distanceLabel: '3 km',
    etaMinutes: 20,
    jeeber: jeeber,
    requestId: 'REQ-9001',
    price: 9,
    currency: 'USD',
    jeeberName: 'Kamal Hajj',
    tier: 'express',
    itemSummary: 'Groceries from Spinneys',
  );

  /// The catalog's `In transit` state, field-for-field the values
  /// `DemoLiveTrackingRepository` serves (minus its wall-clock timestamps).
  ///
  /// Note `jeeber: null` — the demo row carries the summary fields but no
  /// matched-courier object, so the courier CARD is absent while the pinned
  /// header still names "Kamal Hajj". That asymmetry is the shipped shape and is
  /// preserved rather than tidied.
  static const DeliveryTrackingInfo inTransitInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.inTransit,
    stageTimestamps: <TrackingStage, DateTime>{},
    distanceLabel: '3 km',
    etaMinutes: 20,
    requestId: deliveryId,
    price: 9,
    currency: 'USD',
    jeeberName: 'Kamal Hajj',
    tier: 'express',
    itemSummary: 'Groceries from Spinneys',
  );

  /// The hand-over moment: the courier is at the door.
  static const DeliveryTrackingInfo atDoorInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.atDoor,
    stageTimestamps: <TrackingStage, DateTime>{},
    distanceLabel: '0.0 km',
    etaMinutes: 0,
    jeeber: jeeber,
    requestId: 'REQ-9001',
    price: 8.5,
    currency: 'USD',
    jeeberName: 'Rami K.',
    tier: 'standard',
    itemSummary: 'Pharmacy pickup',
  );

  /// Terminal: the delivery was cancelled (sprint-009 scenario matrix #9).
  static const DeliveryTrackingInfo cancelledInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.ordered,
    stageTimestamps: <TrackingStage, DateTime>{},
    lifecycle: TrackingLifecycle.cancelled,
    requestId: 'REQ-9002',
  );

  /// Terminal: the request EXPIRED before it could complete (P6/A3).
  ///
  /// Structurally the twin of [cancelledInfo] and deliberately kept separate:
  /// cancel and expire carry different fee/strike semantics, so the two bodies
  /// must never share copy.
  static const DeliveryTrackingInfo expiredInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.ordered,
    stageTimestamps: <TrackingStage, DateTime>{},
    lifecycle: TrackingLifecycle.expired,
    requestId: 'REQ-9003',
  );

  /// `FailedNeedsEscalation` — parked with admin, NOT terminal (P6/A1).
  ///
  /// The pre-fix symptom this replaced was the ordinary active layout with the
  /// stepper rewound to step 1, polling a row only an admin could move.
  static const DeliveryTrackingInfo underReviewInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.inTransit,
    stageTimestamps: <TrackingStage, DateTime>{},
    lifecycle: TrackingLifecycle.failed,
    requestId: 'REQ-9004',
  );

  /// The layout ceiling: every string at its longest plausible length, on one
  /// row, at the stage that mounts the most sections.
  ///
  /// A Lebanese pharmacy order with a full item list, a courier whose display
  /// name is a full transliterated Arabic name, a three-digit ETA and a price
  /// that carries its unit. Nothing here is longer than the wire allows —
  /// `itemSummary` is the customer's own compose text (G1's `description`
  /// fallback), which has no length cap on the client.
  static const DeliveryTrackingInfo longestInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.picked,
    stageTimestamps: <TrackingStage, DateTime>{},
    distanceLabel: '12.4 km',
    etaMinutes: 145,
    jeeber: JeeberSummary(
      displayName: 'Abdulrahman Al-Muhandis',
      vehicleLabel: 'Motorcycle with insulated box',
    ),
    requestId: 'REQ-9005',
    price: 1234.5,
    currency: 'USD',
    jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
    tier: 'express',
    itemSummary: 'Two bags of groceries from Spinneys Achrafieh, one carton of '
        'bottled water, a pharmacy pickup from Mazen Pharmacy on Weygand '
        'Street, and a sealed envelope from the notary office on the 4th floor',
  );

  // ── Designed states ─────────────────────────────────────────────────────

  /// Builds the cubit both hosts mount above the screen.
  ///
  /// No refresh source (b02 wave C / N7 removed the poll entirely), so a dev
  /// surface reads once and leaks no timers; no position channel, so the marker
  /// axis contributes nothing. [code] seeds the local [HandoverCodeStore] — pass
  /// null to model a device that never received the accept-time code.
  static LiveTrackingCubit cubit(
    LiveTrackingRepository repository, {
    String? code,
  }) =>
      LiveTrackingCubit(
        repository: repository,
        deliveryId: deliveryId,
        refreshSignals: const Stream<void>.empty(),
        handoverCodeStore: code == null
            ? null
            : LiveTrackingScreenMemoryHandoverStore(code),
      );

  /// A cubit over one fixed snapshot, with the hand-over code known by default.
  static LiveTrackingCubit ready(
    DeliveryTrackingInfo info, {
    String? code = handoverCode,
  }) =>
      cubit(LiveTrackingScreenStaticRepository(info), code: code);

  /// The cold read: `GET /v1/deliveries/{id}` is on the wire and nothing has
  /// come back.
  static LiveTrackingCubit loading() =>
      cubit(const LiveTrackingScreenPendingRepository());

  /// The error body, by typed kind. `notFound` is the one that gets its own
  /// heading; the rest render the generic GPS/server layout.
  static LiveTrackingCubit failing(LiveTrackingErrorKind kind) =>
      cubit(LiveTrackingScreenFailingRepository(kind));
}
