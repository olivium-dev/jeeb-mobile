import 'package:flutter/foundation.dart';

import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

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
      requestId: deliveryId,
      price: 9.0,
      currency: 'USD',
      jeeberName: 'Kamal Hajj',
      tier: 'express',
      itemSummary: 'Groceries from Spinneys',
    );
  }
}
