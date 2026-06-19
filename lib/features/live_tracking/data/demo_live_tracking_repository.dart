import 'package:flutter/foundation.dart';

import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

/// Debug-only repository that returns a deterministic in-transit snapshot so
/// the order-tracking screen (Figma 56560:1772) renders its ready state on the
/// dev seam / emulator without a reachable gateway.
///
/// Mirrors the delivery-status `demoDeliverySnapshot` fallback. Never wired in
/// release (the router only selects it under `kDebugMode` + an active dev-seam
/// tracking route).
class DemoLiveTrackingRepository implements LiveTrackingRepository {
  const DemoLiveTrackingRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    assert(kDebugMode, 'DemoLiveTrackingRepository must not run in release');
    final now = DateTime.now();
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: TrackingStage.inTransit,
      stageTimestamps: {
        TrackingStage.ordered: now.subtract(const Duration(minutes: 18)),
        TrackingStage.picked: now.subtract(const Duration(minutes: 9)),
        TrackingStage.inTransit: now.subtract(const Duration(minutes: 4)),
      },
      distanceLabel: '3 km',
      etaMinutes: 20,
      // JM-032: pinned-summary fields so `order_summary_pinned` renders on the
      // dev-seam capture path (no reachable gateway).
      requestId: deliveryId,
      price: 9.0,
      currency: 'USD',
      jeeberName: 'Kamal Hajj',
      tier: 'express',
      itemSummary: 'Groceries from Spinneys',
    );
  }
}
