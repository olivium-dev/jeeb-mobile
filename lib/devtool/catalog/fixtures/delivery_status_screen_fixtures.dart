// Designed states for `DeliveryStatusScreen` — ONE source of truth, two
// consumers.
//
//   lib/devtool/catalog/entries/batch_03_entries.dart
//       the designer-facing, on-device Screen Catalog
//   lib/features/delivery_status/presentation/delivery_status_screen.dart
//       the JEEB PREVIEWS section at its bottom
//
// The catalog owned a private `_statusSnapshot()` builder and a private
// `_ErroringDeliveryStatusGateway`; both are extracted here verbatim in
// meaning, so the two surfaces cannot end up with two different notions of
// "the delivery status screen, in transit".
//
// ## The screen has exactly ONE seam, and it bounds what can be a state
//
// `DeliveryStatusScreen` takes either a pre-built `cubit` or a `gateway`
// (asserted mutually exclusive), and falls back to
// `InMemoryDeliveryStatusGateway(seed: demoDeliverySnapshot(...))` when given
// neither. Every state below drives the `gateway` seam, never `cubit`:
//
//  * `DeliveryStatusCubit` subscribes to the gateway inside its CONSTRUCTOR,
//    so a cubit built outside the widget tree starts streaming before the tree
//    that owns it exists. `test/delivery_status_screen_test.dart` documents the
//    consequence at length — that pending subscription plus the loading
//    spinner's ticker deadlocks `pumpWidget` — and passes a gateway for the
//    same reason.
//  * The cubit has NO `initialState`/seed constructor, so
//    `DeliveryStatusState.isCancelling` (the "Cancelling…" label) cannot be
//    seeded by either surface. The only way to reach it is to tap Cancel and
//    have the gateway's `cancel()` future stay in the air, which is what
//    [DeliveryStatusScreenPendingCancelGateway] is for.
//
// ## Network-free by construction
//
// Every gateway here answers from a const snapshot, throws, or never
// completes. None of them builds a Dio client or touches GetIt, so neither
// surface depends on the `CatalogNetworkGuard` its host installs — that is a
// net, not the plan.
//
// ## Two deliberate departures from the catalog's old private fixtures
//
//  1. **Timestamps are a fixed timeline, not `DateTime.now()`.** The old
//     builder anchored every milestone to the wall clock, so the same designed
//     state rendered different captions every time it was opened and could not
//     be pinned by a render test. Stage captions are absolute times of day
//     ("at 10:04"), never "4 minutes ago", so nothing is lost by fixing the
//     base instant — and the catalog now shows the same card twice in a row.
//  2. **Each state carries its OWN delivery id.** The four catalog states all
//     said `ORD-4821`, so a card that silently rendered its neighbour's fixture
//     looked correct. `Delivery #<id>` is the one per-state string the screen
//     paints, which makes it the cheapest possible tell.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import 'package:jeeb_mobile/features/delivery_status/domain/delivery_address.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_snapshot.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_status_gateway.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_tier.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';

/// One designed state: the id the screen echoes, and the gateway that feeds it.
///
/// Both are needed together — the id is only a subtitle, the timeline lives in
/// the gateway's snapshot — so they travel as a pair rather than as two
/// constants a caller could mismatch.
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
///
/// Local time on purpose: `DeliveryStageIndicator` formats with
/// `DateFormat.Hm(tag).format(when.toLocal())`, so a UTC anchor would render a
/// different caption on every machine. Matches the date
/// `test/delivery_status_screen_test.dart` already uses.
final DateTime deliveryStatusScreenTimelineStart = DateTime(2026, 5, 17, 10);

/// The Jeeber every in-flight state is matched with.
///
/// The same person `test/delivery_status_screen_test.dart` and the demo
/// snapshot use, so the tests, the catalog and the canvas all describe one
/// courier rather than three.
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
///
/// Every stage at or before [stage] is stamped, four minutes apart, starting
/// at [deliveryStatusScreenTimelineStart] — matched 10:00, picked up 10:04, in
/// transit 10:08, delivered 10:12. Later stages are absent from the map, which
/// is exactly what the gateway does and what makes the indicator render
/// "Waiting…" for them.
///
/// Pass `jeeber: null` for the states where no courier is on the snapshot: the
/// pre-match wait, and (as the catalog has always had it) the terminal ones.
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
///
/// This is not a synthetic condition: it is the first frame of EVERY delivery,
/// because `DeliveryStatusState` starts at `mode: loading` and only leaves it
/// when the gateway's first snapshot lands. Holding it open is the only way to
/// inspect that frame without a real slow connection.
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
///
/// Extracted from the catalog's private `_ErroringDeliveryStatusGateway`.
/// `retry()` re-subscribes and gets the same error, so the card is stable to
/// look at and the Retry button is honest about being a no-op here.
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
///
/// The realistic failure — a tunnel, a backgrounded app, a websocket idle
/// timeout — as opposed to "the service was down when you opened the screen".
/// The cubit keeps `state.snapshot`, so this fixture is what makes it visible
/// that the view throws it away: see the preview section in
/// `delivery_status_screen.dart`.
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
///
/// Delegates `watch` to the shipped [InMemoryDeliveryStatusGateway] and only
/// replaces the write, so the state a reviewer taps from is the ordinary
/// pre-pickup one. Because the cubit cannot be seeded (see the header), this
/// is the ONLY way either dev surface can hold `isCancelling: true` still
/// enough to look at.
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
///
/// Every member is a GETTER, not a constant: [InMemoryDeliveryStatusGateway]
/// keeps a `StreamController` per `watch()` call, and the preview canvas mounts
/// many cards at once, so each read hands out a fresh gateway rather than
/// letting two live screens share one fake's bookkeeping.
///
/// The first four are the states the Screen Catalog has shown since DT-04. The
/// rest are reachable only from the preview canvas today; they are kept here,
/// beside their siblings, so that adding them to the catalog later is a
/// one-line change rather than a re-derivation.
abstract final class DeliveryStatusScreenFixtures {
  /// ACTIVE, pre-pickup: the only state where BOTH CTAs render, because
  /// `canCancel` is gated on `stage.isBefore(pickedUp)` (BR-4) and
  /// `canContactJeeber` on the gateway having exposed a phone number.
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
  ///
  /// `jeeber: null` is the catalog's long-standing choice, kept deliberately —
  /// see the preview section for what the screen then does with it.
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
  ///
  /// The empty state of the Jeeber card. Contact is withheld (no number to
  /// dial) while Cancel stays, which is the correct pairing and the only state
  /// that shows the two CTAs decoupled.
  static DeliveryStatusScreenDesignedState get awaitingJeeber =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4826',
        stage: DeliveryStage.matched,
        jeeber: null,
      ));

  /// CANCELLED terminal.
  ///
  /// `stage` stays at `matched` — cancellation is a lifecycle, not a stage —
  /// which is what drives `DeliveryStageIndicator` to zero its stepper while
  /// keeping the milestone timestamps.
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
  ///
  /// A real Beirut address with a landmark line, a courier whose display name
  /// is a full Arabic-transliterated name rather than the privacy-trimmed
  /// "Karim H.", a pickup-truck tier (the longest tier label), a three-digit
  /// ETA, and a gateway reference that is a UUID rather than `ORD-####` —
  /// which the gateway does return for requests created outside the app.
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
  ///
  /// A separate id so a 320-wide card cannot be mistaken for the 390-wide one
  /// in a canvas that renders both.
  static DeliveryStatusScreenDesignedState get compactViewport =>
      _inMemory(deliveryStatusScreenSnapshot(
        id: 'ORD-4830',
        stage: DeliveryStage.inTransit,
        etaMinutes: 12,
      ));

  /// Wraps [snapshot] in the shipped in-memory fake, which emits it on listen
  /// and then holds the stream open — no polling, no timers, no close, so the
  /// screen parks in `ready` for as long as the surface is mounted.
  static DeliveryStatusScreenDesignedState _inMemory(
    DeliverySnapshot snapshot,
  ) =>
      DeliveryStatusScreenDesignedState(
        deliveryId: snapshot.id,
        gateway: InMemoryDeliveryStatusGateway(seed: snapshot),
      );
}
