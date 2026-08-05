import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_controller.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_gateway.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_models.dart';

void main() {
  test(
    'full trip posts every point and stops at the real OTP boundary',
    () async {
      final session = _FakeSession(delivery: _delivery());
      final controller = _controller(session);

      final listed = await controller.connectDriver('jeeber-1');
      await controller.start(
        deliveryId: listed.single.id,
        mode: LocationSimulationMode.fullTrip,
        tripDuration: const Duration(seconds: 2),
      );

      expect(session.transitions, <LocationSimulationDeliveryStatus>[
        LocationSimulationDeliveryStatus.picked,
        LocationSimulationDeliveryStatus.inTransit,
        LocationSimulationDeliveryStatus.atDoor,
      ]);
      expect(session.points, hasLength(3));
      expect(session.points.first.coordinate, _pickup);
      expect(session.points.last.coordinate, _dropoff);
      expect(controller.state.phase, LocationSimulationPhase.awaitingOtp);
      expect(controller.state.acceptedUpdates, 3);
      expect(session.verifiedOtp, isNull);

      await controller.verifyOtp('1234');

      expect(session.verifiedOtp, '1234');
      expect(controller.state.phase, LocationSimulationPhase.completed);
      expect(
        controller.state.deliveryStatus,
        LocationSimulationDeliveryStatus.done,
      );
      controller.dispose();
    },
  );

  test('location-only mode refuses to bypass the InTransit gate', () async {
    final session = _FakeSession(
      delivery: _delivery(status: LocationSimulationDeliveryStatus.picked),
    );
    final controller = _controller(session);
    await controller.connectDriver('jeeber-1');

    await controller.start(
      deliveryId: 'delivery-1',
      mode: LocationSimulationMode.locationOnly,
      tripDuration: const Duration(seconds: 2),
    );

    expect(controller.state.phase, LocationSimulationPhase.failed);
    expect(controller.state.message, contains('requires an InTransit'));
    expect(session.transitions, isEmpty);
    expect(session.points, isEmpty);
    controller.dispose();
  });

  test('pause prevents the next point until resume', () async {
    final firstDelay = Completer<void>();
    var delayCalls = 0;
    final session = _FakeSession(
      delivery: _delivery(status: LocationSimulationDeliveryStatus.inTransit),
    );
    final controller = LocationSimulationController(
      gateway: _FakeGateway(session),
      tickInterval: const Duration(seconds: 1),
      delay: (_) {
        delayCalls++;
        return delayCalls == 1 ? firstDelay.future : Future<void>.value();
      },
      clock: () => DateTime.utc(2026, 8, 5, 12),
    );
    await controller.connectDriver('jeeber-1');

    final run = controller.start(
      deliveryId: 'delivery-1',
      mode: LocationSimulationMode.locationOnly,
      tripDuration: const Duration(seconds: 2),
    );
    await _until(() => session.points.length == 1);
    controller.pause();
    firstDelay.complete();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.phase, LocationSimulationPhase.paused);
    expect(session.points, hasLength(1));

    controller.resume();
    await run;
    expect(session.points, hasLength(3));
    expect(controller.state.phase, LocationSimulationPhase.arrived);
    controller.dispose();
  });

  test(
    '409 reconciles status and stops after the delivery leaves transit',
    () async {
      final session = _FakeSession(
        delivery: _delivery(status: LocationSimulationDeliveryStatus.inTransit),
        postFailure: const LocationSimulationFailure(
          kind: LocationSimulationFailureKind.conflict,
          operation: 'post simulated location',
          message: 'HTTP 409',
          statusCode: 409,
        ),
        reconciliationStatus: LocationSimulationDeliveryStatus.atDoor,
      );
      final controller = _controller(session);
      await controller.connectDriver('jeeber-1');

      await controller.start(
        deliveryId: 'delivery-1',
        mode: LocationSimulationMode.locationOnly,
        tripDuration: const Duration(seconds: 2),
      );

      expect(controller.state.phase, LocationSimulationPhase.failed);
      expect(controller.state.message, contains('AtDoor'));
      expect(session.postAttempts, 1);
      controller.dispose();
    },
  );

  test('rejected location stops without advancing route progress', () async {
    final session = _FakeSession(
      delivery: _delivery(status: LocationSimulationDeliveryStatus.inTransit),
      postResult: const LocationSimulationUpdateResult(
        accepted: 0,
        rejected: 1,
      ),
    );
    final controller = _controller(session);
    await controller.connectDriver('jeeber-1');

    await controller.start(
      deliveryId: 'delivery-1',
      mode: LocationSimulationMode.locationOnly,
      tripDuration: const Duration(seconds: 2),
    );

    expect(controller.state.phase, LocationSimulationPhase.failed);
    expect(controller.state.currentPointIndex, -1);
    expect(controller.state.progress, 0);
    expect(controller.state.acceptedUpdates, 0);
    expect(controller.state.rejectedUpdates, 1);
    expect(controller.state.message, contains('rejected 1'));
    expect(session.postAttempts, 1);
    expect(session.transitions, isEmpty);
    controller.dispose();
  });

  test(
    'full trip never transitions to AtDoor after a rejected point',
    () async {
      final session = _FakeSession(
        delivery: _delivery(status: LocationSimulationDeliveryStatus.inTransit),
        postResult: const LocationSimulationUpdateResult(
          accepted: 0,
          rejected: 1,
        ),
      );
      final controller = _controller(session);
      await controller.connectDriver('jeeber-1');

      await controller.start(
        deliveryId: 'delivery-1',
        mode: LocationSimulationMode.fullTrip,
        tripDuration: const Duration(seconds: 2),
      );

      expect(controller.state.phase, LocationSimulationPhase.failed);
      expect(session.transitions, isEmpty);
      expect(
        session.transitions,
        isNot(contains(LocationSimulationDeliveryStatus.atDoor)),
      );
      expect(session.postAttempts, 1);
      controller.dispose();
    },
  );
}

final _pickup = LocationCoordinate(latitude: 33.8886, longitude: 35.4955);
final _dropoff = LocationCoordinate(latitude: 33.9001, longitude: 35.5034);

LocationSimulationDelivery _delivery({
  LocationSimulationDeliveryStatus status =
      LocationSimulationDeliveryStatus.ordered,
}) {
  return LocationSimulationDelivery(
    id: 'delivery-1',
    status: status,
    pickupLocation: LocationCoordinate(
      latitude: _pickup.latitude,
      longitude: _pickup.longitude,
    ),
    dropoffLocation: LocationCoordinate(
      latitude: _dropoff.latitude,
      longitude: _dropoff.longitude,
    ),
  );
}

LocationSimulationController _controller(_FakeSession session) {
  return LocationSimulationController(
    gateway: _FakeGateway(session),
    tickInterval: const Duration(seconds: 1),
    delay: (_) => Future<void>.value(),
    clock: () => DateTime.utc(2026, 8, 5, 12),
  );
}

class _FakeGateway implements LocationSimulationGateway {
  const _FakeGateway(this.session);

  final _FakeSession session;

  @override
  Future<LocationSimulationSession> openSession({
    required String jeeberUserId,
    required List<String> roles,
  }) async => session;
}

class _FakeSession implements LocationSimulationSession {
  _FakeSession({
    required this.delivery,
    this.postFailure,
    this.reconciliationStatus,
    this.postResult = const LocationSimulationUpdateResult(
      accepted: 1,
      rejected: 0,
    ),
  });

  LocationSimulationDelivery delivery;
  final LocationSimulationFailure? postFailure;
  final LocationSimulationDeliveryStatus? reconciliationStatus;
  final LocationSimulationUpdateResult postResult;
  final List<LocationSimulationDeliveryStatus> transitions =
      <LocationSimulationDeliveryStatus>[];
  final List<LocationRoutePoint> points = <LocationRoutePoint>[];
  int postAttempts = 0;
  String? verifiedOtp;

  @override
  Future<LocationSimulationDelivery> getDelivery(String deliveryId) async {
    if (postAttempts > 0 && reconciliationStatus != null) {
      return _delivery(status: reconciliationStatus!);
    }
    return delivery;
  }

  @override
  Future<List<LocationSimulationDeliverySummary>> listDeliveries() async =>
      <LocationSimulationDeliverySummary>[
        LocationSimulationDeliverySummary(
          id: delivery.id,
          status: delivery.status,
        ),
      ];

  @override
  Future<LocationSimulationUpdateResult> postLocation({
    required String deliveryId,
    required LocationRoutePoint point,
  }) async {
    postAttempts++;
    if (postFailure != null) throw postFailure!;
    points.add(point);
    return postResult;
  }

  @override
  Future<void> transitionDelivery({
    required String deliveryId,
    required LocationSimulationDeliveryStatus to,
  }) async {
    transitions.add(to);
    delivery = LocationSimulationDelivery(
      id: delivery.id,
      status: to,
      requestId: delivery.requestId,
      pickupLocation: delivery.pickupLocation,
      dropoffLocation: delivery.dropoffLocation,
    );
  }

  @override
  Future<void> verifyOtp({
    required String deliveryId,
    required String code,
  }) async {
    verifiedOtp = code;
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
