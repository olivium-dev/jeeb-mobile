// Shared dev-only fixtures for `LiveTrackingScreen` (JM-032 `order-tracking`).

import 'dart:async';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/courier_position_channel.dart';
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
/// The cubit starts in `loading` and leaves it on the first emit, so a fixture
class LiveTrackingScreenPendingRepository implements LiveTrackingRepository {
  const LiveTrackingScreenPendingRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) =>
      Completer<DeliveryTrackingInfo>().future;
}

/// Serves one snapshot on the FIRST read and then fails: the warm-failure
/// lane, where the rows stay and a note appears above them.
class LiveTrackingScreenWarmFailingRepository implements LiveTrackingRepository {
  LiveTrackingScreenWarmFailingRepository(
    this.info, {
    this.kind = LiveTrackingErrorKind.network,
  });

  final DeliveryTrackingInfo info;
  final LiveTrackingErrorKind kind;

  int reads = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    reads++;
    if (reads == 1) return info;
    throw LiveTrackingException(kind);
  }
}

/// Reads fine, but every live-position read comes back null: after three the
/// cubit synthesises `PositionFreshness.lost` (UX-11).
class LiveTrackingScreenSilentPositionRepository
    implements LiveTrackingRepository, LivePositionSource {
  const LiveTrackingScreenSilentPositionRepository(this.info);

  final DeliveryTrackingInfo info;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      info;

  @override
  Future<DeliveryLivePosition?> fetchLivePosition({
    required String deliveryId,
  }) async =>
      null;
}

/// A channel that always refuses to open, with a stated reason (NET-05).
class LiveTrackingScreenRefusingChannel
    implements CourierPositionChannel, CourierPositionChannelOutcome {
  const LiveTrackingScreenRefusingChannel({
    this.failure = CourierPositionOpenFailure.authRejected,
  });

  final CourierPositionOpenFailure failure;

  @override
  Future<Stream<CourierPositionFix>?> open({required String deliveryId}) async =>
      null;

  @override
  Future<CourierPositionOpenResult> openWithOutcome({
    required String deliveryId,
  }) async =>
      CourierPositionOpenResult.failed(failure);
}

/// In-memory [HandoverCodeStore] — the local, accept-time source of the G4
/// hand-over code.
/// This is the ONLY way to put a code on this screen. The cubit deliberately
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
/// Every builder returns a FRESH cubit — both hosts rebuild on every open, and a
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
  /// The genuinely EMPTY reading of the active layout — `hasSummary` is false
  static const DeliveryTrackingInfo orderedInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.ordered,
    stageTimestamps: <TrackingStage, DateTime>{},
    requestId: 'REQ-9001',
  );

  /// Picked up, courier assigned, summary complete — the reference reading.
  /// Every optional section of `_TrackingBody` is mounted at once: the pinned
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
  static const DeliveryTrackingInfo inTransitInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.inTransit,
    stageTimestamps: <TrackingStage, DateTime>{},
    distanceLabel: '3 km',
    etaMinutes: 20,
    jeeber: jeeber,
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
  /// Structurally the twin of [cancelledInfo] and deliberately kept separate:
  static const DeliveryTrackingInfo expiredInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.ordered,
    stageTimestamps: <TrackingStage, DateTime>{},
    lifecycle: TrackingLifecycle.expired,
    requestId: 'REQ-9003',
  );

  /// `FailedNeedsEscalation` — parked with admin, NOT terminal (P6/A1).
  /// The pre-fix symptom this replaced was the ordinary active layout with the
  static const DeliveryTrackingInfo underReviewInfo = DeliveryTrackingInfo(
    deliveryId: deliveryId,
    currentStage: TrackingStage.inTransit,
    stageTimestamps: <TrackingStage, DateTime>{},
    lifecycle: TrackingLifecycle.failed,
    requestId: 'REQ-9004',
  );

  /// The layout ceiling: every string at its longest plausible length, on one
  /// row, at the stage that mounts the most sections.
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
  /// No refresh source (b02 wave C / N7 removed the poll entirely), so a dev
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
