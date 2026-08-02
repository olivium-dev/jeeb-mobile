// Designed states for `DeliveryStatusScreen` — ONE source of truth, two

import 'dart:async';

import 'package:jeeb_mobile/features/delivery_status/domain/delivery_address.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_snapshot.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_status_gateway.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_tier.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';

/// One designed state: the id the screen echoes, and the gateway that feeds it.
/// Both are needed together — the id is only a subtitle, the timeline lives in
final class DeliveryStatusScreenDesignedState {
  const DeliveryStatusScreenDesignedState({
    required this.deliveryId,
    required this.gateway,
  });

  /// Echoed by the screen as `Delivery #<id>` and used as the cubit's key.
  final String deliveryId;

  /// The stream + cancel channel behind this state. Always a local fake.
  final DeliveryStatusGateway gateway;
}

/// The instant every fixed milestone timeline is anchored to.
/// Local time on purpose: `DeliveryStageIndicator` formats with
final DateTime deliveryStatusScreenTimelineStart = DateTime(2026, 5, 17, 10);

/// The Jeeber every in-flight state is matched with.
/// The same person `test/delivery_status_screen_test.dart` and the demo
const JeeberSummary deliveryStatusScreenJeeber = JeeberSummary(
  displayName: 'Karim H.',
  vehicleLabel: 'Scooter',
  phoneE164: '+96171000000',
  rating: 4.8,
);

const DeliveryAddress _pickup = DeliveryAddress(
  label: 'Hamra Main St, Beirut',
  detail: 'Apt 4B, Floor 3',
);

const DeliveryAddress _dropoff = DeliveryAddress(
  label: 'Verdun, Beirut',
  detail: 'Reception desk',
);

/// Builds a snapshot with a deterministic milestone timeline.
/// Every stage at or before [stage] is stamped, four minutes apart, starting
DeliverySnapshot deliveryStatusScreenSnapshot({
  required String id,
  required DeliveryStage stage,
  DeliveryLifecycle lifecycle = DeliveryLifecycle.active,
  JeeberSummary? jeeber = deliveryStatusScreenJeeber,
  int? etaMinutes,
  DeliveryAddress pickup = _pickup,
  DeliveryAddress dropoff = _dropoff,
  DeliveryTier tier = DeliveryTier.scooter,
}) {
  final timestamps = <DeliveryStage, DateTime>{
    for (final DeliveryStage s in DeliveryStage.values)
      if (!stage.isBefore(s))
        s: deliveryStatusScreenTimelineStart.add(Duration(minutes: s.order * 4)),
  };
  return DeliverySnapshot(
    id: id,
    stage: stage,
    lifecycle: lifecycle,
    stageTimestamps: timestamps,
    pickup: pickup,
    dropoff: dropoff,
    tier: tier,
    jeeber: jeeber,
    etaMinutes: etaMinutes,
  );
}

/// A stream that never emits and never closes — the cold-load state.
/// This is not a synthetic condition: it is the first frame of EVERY delivery,
/// because `DeliveryStatusState` starts at `mode: loading` and only leaves it
class DeliveryStatusScreenPendingGateway implements DeliveryStatusGateway {
  const DeliveryStatusScreenPendingGateway();

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) =>
      Stream<DeliverySnapshot>.fromFuture(Completer<DeliverySnapshot>().future);

  @override
  Future<CancellationOutcome> cancel(String deliveryId) =>
      Completer<CancellationOutcome>().future;
}

/// A stream that fails on subscribe — the D30 error state.
/// Extracted from the catalog's private `_ErroringDeliveryStatusGateway`.
/// `retry()` re-subscribes and gets the same error, so the card is stable to
class DeliveryStatusScreenErroringGateway implements DeliveryStatusGateway {
  const DeliveryStatusScreenErroringGateway();

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) =>
      Stream<DeliverySnapshot>.error(StateError('stream lost (fixture)'));

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async =>
      CancellationOutcome.networkError;
}

/// A stream that delivers ONE good snapshot and then drops.
/// The realistic failure — a tunnel, a backgrounded app, a websocket idle
/// timeout — as opposed to "the service was down when you opened the screen".
class DeliveryStatusScreenDroppedStreamGateway implements DeliveryStatusGateway {
  const DeliveryStatusScreenDroppedStreamGateway(this.lastGoodSnapshot);

  /// The snapshot the user saw for one frame before the transport died.
  final DeliverySnapshot lastGoodSnapshot;

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) async* {
    yield lastGoodSnapshot;
    throw StateError('transport dropped after the first snapshot (fixture)');
  }

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async =>
      CancellationOutcome.networkError;
}

/// A live delivery whose `cancel()` never lands.
/// Delegates `watch` to the shipped [InMemoryDeliveryStatusGateway] and only
/// replaces the write, so the state a reviewer taps from is the ordinary
class DeliveryStatusScreenPendingCancelGateway
    implements DeliveryStatusGateway {
  DeliveryStatusScreenPendingCancelGateway(this.seed)
      : _inner = InMemoryDeliveryStatusGateway(seed: seed);

  /// The snapshot the screen shows before Cancel is tapped.
  final DeliverySnapshot seed;

  final InMemoryDeliveryStatusGateway _inner;

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) => _inner.watch(deliveryId);

  @override
  Future<CancellationOutcome> cancel(String deliveryId) =>
      Completer<CancellationOutcome>().future;
}

/// The designed states, named once for both dev surfaces.
/// Every member is a GETTER, not a constant: [InMemoryDeliveryStatusGateway]
abstract final class DeliveryStatusScreenFixtures {
  /// ACTIVE, pre-pickup: the only state where BOTH CTAs render, because
  /// `canCancel` is gated on `stage.isBefore(pickedUp)` (BR-4) and
  static DeliveryStatusScreenDesignedState get matched =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4821',
        stage: DeliveryStage.matched,
      ));

  /// ACTIVE, parcel in hand and moving: the ETA badge appears (the only stage
  /// where `isEtaVisible` is true) and Cancel disappears.
  static DeliveryStatusScreenDesignedState get inTransit =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4822',
        stage: DeliveryStage.inTransit,
        etaMinutes: 8,
      ));

  /// COMPLETED terminal: the banner appears and both CTAs collapse.
  /// `jeeber: null` is the catalog's long-standing choice, kept deliberately —
  static DeliveryStatusScreenDesignedState get delivered =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4823',
        stage: DeliveryStage.delivered,
        lifecycle: DeliveryLifecycle.completed,
        jeeber: null,
      ));

  /// The transport was already down when the screen opened.
  static DeliveryStatusScreenDesignedState get streamLostOnOpen =>
      const DeliveryStatusScreenDesignedState(
        deliveryId: 'ORD-4824',
        gateway: DeliveryStatusScreenErroringGateway(),
      );

  /// Cold start — the first frame of every delivery, held open.
  static DeliveryStatusScreenDesignedState get connecting =>
      const DeliveryStatusScreenDesignedState(
        deliveryId: 'ORD-4825',
        gateway: DeliveryStatusScreenPendingGateway(),
      );

  /// ACTIVE, matched, but the snapshot carries NO courier.
  /// The empty state of the Jeeber card. Contact is withheld (no number to
  static DeliveryStatusScreenDesignedState get awaitingJeeber =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4826',
        stage: DeliveryStage.matched,
        jeeber: null,
      ));

  /// CANCELLED terminal.
  /// `stage` stays at `matched` — cancellation is a lifecycle, not a stage —
  static DeliveryStatusScreenDesignedState get cancelled =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4827',
        stage: DeliveryStage.matched,
        lifecycle: DeliveryLifecycle.cancelled,
        jeeber: null,
      ));

  /// A good snapshot, then the transport drops.
  static DeliveryStatusScreenDesignedState get streamDroppedMidDelivery =>
      DeliveryStatusScreenDesignedState(
        deliveryId: 'ORD-4828',
        gateway: DeliveryStatusScreenDroppedStreamGateway(
          deliveryStatusScreenSnapshot(
            id: 'ORD-4828',
            stage: DeliveryStage.inTransit,
            etaMinutes: 6,
          ),
        ),
      );

  /// Cancel tapped, `POST` still in the air.
  static DeliveryStatusScreenDesignedState get cancelInFlight =>
      DeliveryStatusScreenDesignedState(
        deliveryId: 'ORD-4829',
        gateway: DeliveryStatusScreenPendingCancelGateway(
          deliveryStatusScreenSnapshot(
            id: 'ORD-4829',
            stage: DeliveryStage.matched,
          ),
        ),
      );

  /// The longest plausible content on every axis at once.
  /// A real Beirut address with a landmark line, a courier whose display name
  static DeliveryStatusScreenDesignedState get longestContent =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'REQ-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
        stage: DeliveryStage.inTransit,
        etaMinutes: 240,
        jeeber: const JeeberSummary(
          displayName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
          vehicleLabel: 'Pickup truck (refrigerated)',
          phoneE164: '+96171000000',
          rating: 4.8,
        ),
        pickup: const DeliveryAddress(
          label: 'Rue Abdel Aziz, Hamra, Ras Beirut, Beirut Governorate',
          detail: 'Building Al-Nahda, Apartment 12B, Floor 3, near the '
              'AUB Medical Centre gate',
        ),
        dropoff: const DeliveryAddress(
          label: 'Boulevard Fouad Chehab, Achrafieh, Beirut Governorate',
          detail: 'Reception desk, Tower 2, ask for the night porter after '
              '20:00',
        ),
        tier: DeliveryTier.pickup,
      ));

  /// The in-transit reading again, on the narrowest supported viewport.
  /// A separate id so a 320-wide card cannot be mistaken for the 390-wide one
  static DeliveryStatusScreenDesignedState get compactViewport =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4830',
        stage: DeliveryStage.inTransit,
        etaMinutes: 12,
      ));

  /// Wraps [snapshot] in the shipped in-memory fake, which emits it on listen
  /// and then holds the stream open — no polling, no timers, no close, so the
  static DeliveryStatusScreenDesignedState _inMemory(
    DeliverySnapshot snapshot,
  ) =>
      DeliveryStatusScreenDesignedState(
        deliveryId: snapshot.id,
        gateway: InMemoryDeliveryStatusGateway(seed: snapshot),
      );
}
