import 'dart:async';

import 'delivery_address.dart';
import 'delivery_snapshot.dart';
import 'delivery_stage.dart';
import 'delivery_tier.dart';
import 'jeeber_summary.dart';

/// Outcome of a sender-initiated cancellation request.
///
/// The cubit translates these into one-shot toasts; `success` triggers a
/// terminal-state re-render of the screen.
enum CancellationOutcome {
  success,
  tooLate,
  networkError,
}

/// Side-channel the cubit uses to read live status and submit user actions.
///
/// The interface intentionally hides the transport — the production binding
/// will sit on a realtime-communication-service websocket (per REUSE-MAP.md),
/// but a polling fallback or in-memory fake (used by tests + UI-only
/// milestones) both satisfy the same contract.
abstract class DeliveryStatusGateway {
  /// Continuous stream of snapshots for [deliveryId]. The implementation is
  /// expected to emit an initial snapshot synchronously after subscribe and
  /// every subsequent server update thereafter. The stream is single-
  /// subscription per cubit instance.
  Stream<DeliverySnapshot> watch(String deliveryId);

  /// Sender-initiated cancel. Returns one of [CancellationOutcome] —
  /// `tooLate` is the gateway's response when the courier already picked up.
  Future<CancellationOutcome> cancel(String deliveryId);
}

/// In-memory fake used by widget tests and the UI-only milestone.
///
/// Lets tests script the snapshot timeline (`scriptedSnapshots`) and the
/// cancel outcome (`cancelOutcome`) without standing up the websocket or
/// the gateway HTTP route. Production code wires the real binding via DI;
/// this fake is the only implementation that lives in the mobile repo.
class InMemoryDeliveryStatusGateway implements DeliveryStatusGateway {
  InMemoryDeliveryStatusGateway({
    List<DeliverySnapshot>? scriptedSnapshots,
    this.cancelOutcome = CancellationOutcome.success,
    DeliverySnapshot? seed,
  })  : _scripted = scriptedSnapshots ?? const [],
        _seed = seed;

  final List<DeliverySnapshot> _scripted;
  final DeliverySnapshot? _seed;
  final CancellationOutcome cancelOutcome;

  StreamController<DeliverySnapshot>? _controller;

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) {
    final controller = StreamController<DeliverySnapshot>(sync: true);
    // ignore: close_sinks — the controller's lifecycle is bound to the
    // cubit's subscription cancellation; the cubit calls .cancel() on
    // close which closes this stream.
    _controller = controller;
    final initial = _seed ?? _scripted.firstOrNull;
    final pending = [
      ?initial,
      ..._scripted.skip(_seed == null ? 1 : 0),
    ];
    controller.onListen = () {
      // Emit synchronously once the cubit's listener attaches so test
      // bodies that act on the cubit immediately after construction see
      // the seed snapshot. sync:true on the controller ensures these
      // calls reach the listener in the same microtask.
      for (final snapshot in pending) {
        if (!controller.isClosed) controller.add(snapshot);
      }
    };
    controller.onCancel = () {
      if (!controller.isClosed) controller.close();
      if (identical(_controller, controller)) _controller = null;
    };
    return controller.stream;
  }

  /// Test-only hook so tests can push a snapshot after subscription —
  /// simulates a server-side state change.
  void push(DeliverySnapshot snapshot) {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.add(snapshot);
  }

  /// Test-only hook so tests can simulate a transport failure that closes
  /// the stream prematurely.
  void closeStream() {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.close();
    _controller = null;
  }

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async => cancelOutcome;
}

/// A demo snapshot used by the UI-only milestone screen so the developer can
/// open the route without a backend. Production never sees this — the real
/// gateway always yields its own first snapshot.
DeliverySnapshot demoDeliverySnapshot({
  String id = 'demo-delivery',
  DeliveryStage stage = DeliveryStage.matched,
}) {
  final now = DateTime.now();
  final timestamps = <DeliveryStage, DateTime>{};
  for (final s in DeliveryStage.values) {
    if (!stage.isBefore(s)) {
      timestamps[s] = now.subtract(
        Duration(minutes: (stage.order - s.order + 1) * 4),
      );
    }
  }
  return DeliverySnapshot(
    id: id,
    stage: stage,
    lifecycle: DeliveryLifecycle.active,
    stageTimestamps: timestamps,
    pickup: const DeliveryAddress(
      label: 'Hamra Main St, Beirut',
      detail: 'Apt 4B, Floor 3',
    ),
    dropoff: const DeliveryAddress(
      label: 'Verdun, Beirut',
      detail: 'Reception desk',
    ),
    tier: DeliveryTier.scooter,
    jeeber: const JeeberSummary(
      displayName: 'Karim H.',
      vehicleLabel: 'Scooter',
      phoneE164: '+96171000000',
      rating: 4.8,
    ),
    etaMinutes: stage == DeliveryStage.inTransit ? 8 : null,
  );
}
