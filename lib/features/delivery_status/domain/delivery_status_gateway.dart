import 'dart:async';

import 'delivery_address.dart';
import 'delivery_snapshot.dart';
import 'delivery_stage.dart';
import 'delivery_tier.dart';
import 'jeeber_summary.dart';

enum CancellationOutcome {
  success,
  tooLate,
  networkError,
}

abstract class DeliveryStatusGateway {
  Stream<DeliverySnapshot> watch(String deliveryId);

  Future<CancellationOutcome> cancel(String deliveryId);
}

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
    // ignore: close_sinks — controller lifecycle bound to cubit subscription; cubit calls cancel() which closes stream.
    _controller = controller;
    final initial = _seed ?? _scripted.firstOrNull;
    final pending = [
      if (initial != null) initial,
      ..._scripted.skip(_seed == null ? 1 : 0),
    ];
    controller.onListen = () {
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

  void push(DeliverySnapshot snapshot) {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.add(snapshot);
  }

  void closeStream() {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.close();
    _controller = null;
  }

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async => cancelOutcome;
}

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
