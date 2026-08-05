import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_gateway.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_models.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulator_page.dart';

void main() {
  testWidgets('full-trip UI moves to OTP and completes through verification', (
    tester,
  ) async {
    final session = _PageSession();
    await tester.pumpWidget(
      MaterialApp(
        home: LocationSimulatorPage(
          loadUsers: () async => const <DevUser>[
            DevUser(
              id: 'jeeber-1',
              username: 'nour-driver',
              displayName: 'Nour Driver',
              role: 'customer',
              roles: <String>['customer', 'driver'],
              status: 'active',
            ),
            DevUser(
              id: 'client-1',
              username: 'client-user',
              role: 'client',
              roles: <String>['customer'],
              status: 'active',
            ),
          ],
          simulationGateway: _PageGateway(session),
          tickInterval: const Duration(seconds: 60),
          delay: (_) async {},
          clock: () => DateTime.utc(2026, 8, 5, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nour Driver'), findsOneWidget);
    expect(find.textContaining('delivery-1'), findsOneWidget);
    expect(find.text('client-user'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('locationSimulator.start')));
    await tester.pumpAndSettle();

    expect(find.text('At the door'), findsOneWidget);
    expect(find.text('Accepted  2'), findsOneWidget);
    expect(session.transitions, <LocationSimulationDeliveryStatus>[
      LocationSimulationDeliveryStatus.picked,
      LocationSimulationDeliveryStatus.inTransit,
      LocationSimulationDeliveryStatus.atDoor,
    ]);

    final otpField = find.byKey(const ValueKey('locationSimulator.otp'));
    await tester.scrollUntilVisible(
      otpField,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(otpField, '2468');
    await tester.tap(find.byKey(const ValueKey('locationSimulator.verifyOtp')));
    await tester.pumpAndSettle();

    expect(session.verifiedOtp, '2468');
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('empty assignment state explains the required live setup', (
    tester,
  ) async {
    final session = _PageSession(hasDelivery: false);
    await tester.pumpWidget(
      MaterialApp(
        home: LocationSimulatorPage(
          loadUsers: () async => const <DevUser>[
            DevUser(
              id: 'jeeber-1',
              username: 'Karim Driver',
              role: 'customer',
              roles: <String>['customer', 'driver'],
              status: 'active',
            ),
          ],
          simulationGateway: _PageGateway(session),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('No active delivery is assigned'),
      findsOneWidget,
    );
    expect(find.textContaining('disposable dev request'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('locationSimulator.start')),
          )
          .onPressed,
      isNull,
    );
  });
}

class _PageGateway implements LocationSimulationGateway {
  const _PageGateway(this.session);

  final _PageSession session;

  @override
  Future<LocationSimulationSession> openSession({
    required String jeeberUserId,
    required List<String> roles,
  }) async {
    expect(jeeberUserId, 'jeeber-1');
    expect(roles, <String>['customer', 'driver']);
    return session;
  }
}

class _PageSession implements LocationSimulationSession {
  _PageSession({this.hasDelivery = true});

  final bool hasDelivery;
  final List<LocationSimulationDeliveryStatus> transitions =
      <LocationSimulationDeliveryStatus>[];
  String? verifiedOtp;

  LocationSimulationDeliveryStatus status =
      LocationSimulationDeliveryStatus.ordered;

  LocationSimulationDelivery get delivery => LocationSimulationDelivery(
    id: 'delivery-1',
    status: status,
    pickupLocation: LocationCoordinate(latitude: 33.8886, longitude: 35.4955),
    dropoffLocation: LocationCoordinate(latitude: 33.9001, longitude: 35.5034),
  );

  @override
  Future<LocationSimulationDelivery> getDelivery(String deliveryId) async =>
      delivery;

  @override
  Future<List<LocationSimulationDeliverySummary>> listDeliveries() async =>
      hasDelivery
      ? <LocationSimulationDeliverySummary>[
          LocationSimulationDeliverySummary(id: delivery.id, status: status),
        ]
      : const <LocationSimulationDeliverySummary>[];

  @override
  Future<LocationSimulationUpdateResult> postLocation({
    required String deliveryId,
    required LocationRoutePoint point,
  }) async => const LocationSimulationUpdateResult(accepted: 1, rejected: 0);

  @override
  Future<void> transitionDelivery({
    required String deliveryId,
    required LocationSimulationDeliveryStatus to,
  }) async {
    transitions.add(to);
    status = to;
  }

  @override
  Future<void> verifyOtp({
    required String deliveryId,
    required String code,
  }) async {
    verifiedOtp = code;
    status = LocationSimulationDeliveryStatus.done;
  }
}
