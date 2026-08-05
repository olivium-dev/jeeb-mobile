import 'location_simulation_models.dart';

abstract interface class LocationSimulationGateway {
  Future<LocationSimulationSession> openSession({
    required String jeeberUserId,
    required List<String> roles,
  });
}

abstract interface class LocationSimulationSession {
  Future<List<LocationSimulationDeliverySummary>> listDeliveries();

  Future<LocationSimulationDelivery> getDelivery(String deliveryId);

  Future<void> transitionDelivery({
    required String deliveryId,
    required LocationSimulationDeliveryStatus to,
  });

  Future<LocationSimulationUpdateResult> postLocation({
    required String deliveryId,
    required LocationRoutePoint point,
  });

  Future<void> verifyOtp({required String deliveryId, required String code});
}
