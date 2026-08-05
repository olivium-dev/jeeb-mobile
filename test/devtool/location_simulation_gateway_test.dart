import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/location_simulation/dio_location_simulation_gateway.dart';
import 'package:jeeb_mobile/devtool/location_simulation/location_simulation_models.dart';

class _MockDevGatewayClient extends Mock implements DevGatewayClient {}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

const Map<String, Object?> _detailBody = <String, Object?>{
  'id': 'delivery-1',
  'requestId': 'request-9',
  'clientId': 'client-user-1',
  'jeeberId': 'jeeber-user-7',
  'status': 'InTransit',
  'pickupLocation': <String, Object?>{'lat': 33.8886, 'lng': 35.4955},
  'dropoffLocation': <String, Object?>{'lat': 33.9001, 'lng': 35.5034},
};

void main() {
  late _MockDevGatewayClient tokenClient;

  setUp(() {
    tokenClient = _MockDevGatewayClient();
    when(
      () => tokenClient.mintTokenForUser(any(), roles: any(named: 'roles')),
    ).thenAnswer((_) async => 'selected-jeeber-token');
  });

  DioLocationSimulationGateway gatewayOn(_ScriptedAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'))
      ..httpClientAdapter = adapter;
    return DioLocationSimulationGateway(
      dio: dio,
      devGatewayClient: tokenClient,
    );
  }

  group('DioLocationSimulationGateway', () {
    test(
      'mints once and uses the selected Jeeber bearer on every call',
      () async {
        final adapter = _ScriptedAdapter((options) {
          if (options.method == 'GET' && options.path == '/v1/deliveries') {
            return _json(<String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'id': 'delivery-1',
                  'requestId': 'request-9',
                  'jeeberId': 'jeeber-user-7',
                  'status': 'InTransit',
                },
              ],
            });
          }
          if (options.method == 'GET' &&
              options.path == '/v1/deliveries/delivery-1') {
            return _json(_detailBody);
          }
          if (options.method == 'POST' && options.path == '/location/update') {
            return _json(<String, Object?>{'accepted': 1, 'rejected': 0});
          }
          return _json(<String, Object?>{'ok': true});
        });
        final session = await gatewayOn(adapter).openSession(
          jeeberUserId: ' jeeber-user-7 ',
          roles: const <String>['customer', 'driver'],
        );

        final deliveries = await session.listDeliveries();
        final detail = await session.getDelivery('delivery-1');
        await session.transitionDelivery(
          deliveryId: detail.id,
          to: LocationSimulationDeliveryStatus.picked,
        );
        final locationResult = await session.postLocation(
          deliveryId: detail.id,
          point: LocationRoutePoint(
            coordinate: LocationCoordinate(latitude: 33.89, longitude: 35.50),
            accuracyMeters: 4.5,
            capturedAt: DateTime.utc(2026, 8, 5, 12, 30),
            distanceFromStartMeters: 120,
            speedMetersPerSecond: 6,
            bearingDegrees: 42,
          ),
        );
        await session.verifyOtp(deliveryId: detail.id, code: ' 1234 ');

        verify(
          () => tokenClient.mintTokenForUser(
            'jeeber-user-7',
            roles: const <String>['customer', 'driver'],
          ),
        ).called(1);
        expect(deliveries.single.id, 'delivery-1');
        expect(deliveries.single.requestId, 'request-9');
        expect(
          deliveries.single.status,
          LocationSimulationDeliveryStatus.inTransit,
        );
        expect(detail.id, 'delivery-1');
        expect(detail.requestId, 'request-9');
        expect(detail.pickupLocation.latitude, 33.8886);
        expect(detail.dropoffLocation.longitude, 35.5034);
        expect(
          locationResult,
          const LocationSimulationUpdateResult(accepted: 1, rejected: 0),
        );

        expect(adapter.requests, hasLength(5));
        expect(
          adapter.requests.every(
            (request) =>
                request.headers['Authorization'] ==
                'Bearer selected-jeeber-token',
          ),
          isTrue,
        );

        final listRequest = adapter.requests[0];
        expect(listRequest.method, 'GET');
        expect(listRequest.path, '/v1/deliveries');
        expect(listRequest.queryParameters, <String, dynamic>{
          'role': 'jeeber',
          'page': 1,
          'pageSize': 100,
        });

        final detailRequest = adapter.requests[1];
        expect(detailRequest.method, 'GET');
        expect(detailRequest.path, '/v1/deliveries/delivery-1');

        final transitionRequest = adapter.requests[2];
        expect(transitionRequest.method, 'PATCH');
        expect(transitionRequest.path, '/v1/deliveries/delivery-1/status');
        expect(transitionRequest.data, <String, dynamic>{
          'to': 'Picked',
          'evidenceUrl': null,
        });

        final locationRequest = adapter.requests[3];
        expect(locationRequest.method, 'POST');
        expect(locationRequest.path, '/location/update');
        expect(locationRequest.data, <String, dynamic>{
          'deliveryId': 'delivery-1',
          'points': <Map<String, dynamic>>[
            <String, dynamic>{
              'lat': 33.89,
              'lng': 35.50,
              'accuracy': 4.5,
              'timestamp': '2026-08-05T12:30:00.000Z',
            },
          ],
        });
        expect(
          (locationRequest.data as Map<String, dynamic>)['points'],
          isNot(contains(<String, dynamic>{'speed': 6, 'bearing': 42})),
        );

        final otpRequest = adapter.requests[4];
        expect(otpRequest.method, 'POST');
        expect(otpRequest.path, '/v1/deliveries/delivery-1/otp/verify');
        expect(otpRequest.data, <String, dynamic>{'code': '1234'});
      },
    );

    test(
      'does not collapse a list HTTP failure into an empty result',
      () async {
        final adapter = _ScriptedAdapter(
          (_) => _json(<String, Object?>{
            'detail': 'temporarily unavailable',
          }, status: 503),
        );
        final session = await gatewayOn(adapter).openSession(
          jeeberUserId: 'jeeber-user-7',
          roles: const <String>['customer', 'driver'],
        );

        await expectLater(
          session.listDeliveries(),
          throwsA(
            isA<LocationSimulationFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  LocationSimulationFailureKind.server,
                )
                .having((failure) => failure.statusCode, 'statusCode', 503)
                .having(
                  (failure) => failure.responseBody,
                  'responseBody',
                  <String, dynamic>{'detail': 'temporarily unavailable'},
                ),
          ),
        );
      },
    );

    test(
      'reports invalid detail coordinates as a typed response failure',
      () async {
        final adapter = _ScriptedAdapter(
          (_) => _json(<String, Object?>{
            ..._detailBody,
            'dropoffLocation': <String, Object?>{'lat': 95, 'lng': 35.5034},
          }),
        );
        final session = await gatewayOn(adapter).openSession(
          jeeberUserId: 'jeeber-user-7',
          roles: const <String>['customer', 'driver'],
        );

        await expectLater(
          session.getDelivery('delivery-1'),
          throwsA(
            isA<LocationSimulationFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  LocationSimulationFailureKind.invalidResponse,
                )
                .having((failure) => failure.statusCode, 'statusCode', 200),
          ),
        );
      },
    );

    test('accepts forthcoming snake_case detail coordinates', () async {
      final adapter = _ScriptedAdapter(
        (_) => _json(<String, Object?>{
          'delivery_id': 'delivery-1',
          'request_id': 'request-9',
          'client_id': 'client-user-1',
          'jeeber_id': 'jeeber-user-7',
          'status': 'InTransit',
          'pickup_location': <String, Object?>{'lat': 33.8886, 'lng': 35.4955},
          'dropoff_location': <String, Object?>{'lat': 33.9001, 'lng': 35.5034},
        }),
      );
      final session = await gatewayOn(adapter).openSession(
        jeeberUserId: 'jeeber-user-7',
        roles: const <String>['customer', 'driver'],
      );

      final detail = await session.getDelivery('delivery-1');

      expect(detail.id, 'delivery-1');
      expect(detail.clientUserId, 'client-user-1');
      expect(detail.jeeberUserId, 'jeeber-user-7');
      expect(detail.pickupLocation.latitude, 33.8886);
      expect(detail.dropoffLocation.longitude, 35.5034);
      expect(adapter.requests, hasLength(1));
    });

    test('does not expose an unknown gateway status as simulatable', () async {
      final adapter = _ScriptedAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'delivery-new-status',
              'jeeberId': 'jeeber-user-7',
              'status': 'AwaitingDrone',
            },
          ],
        }),
      );
      final session = await gatewayOn(adapter).openSession(
        jeeberUserId: 'jeeber-user-7',
        roles: const <String>['customer', 'driver'],
      );

      final deliveries = await session.listDeliveries();

      expect(deliveries, isEmpty);
    });

    test(
      'scopes mixed live list rows and recovers coordinates from owner read',
      () async {
        when(
          () => tokenClient.mintTokenForUser(
            'client-user-1',
            roles: const <String>['customer'],
          ),
        ).thenAnswer((_) async => 'owner-read-token');
        final adapter = _ScriptedAdapter((options) {
          if (options.path == '/v1/deliveries') {
            return _json(<String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'id': 'assigned-active',
                  'requestId': 'request-for-assigned-active',
                  'status': 'InTransit',
                  'jeeberId': 'jeeber-user-7',
                  'pickup': <String, Object?>{
                    'address': 'Current location (52.3995, 5.2751)',
                  },
                  'dropoff': <String, Object?>{
                    'address': 'Current location (52.3995, 5.2751)',
                  },
                },
                <String, Object?>{
                  'id': 'client-owned-other-driver',
                  'status': 'InTransit',
                  'jeeberId': 'other-driver',
                },
                <String, Object?>{
                  'id': 'assigned-terminal',
                  'status': 'Done',
                  'jeeberId': 'jeeber-user-7',
                },
              ],
              'page': 1,
              'pageSize': 100,
              'totalCount': 3,
              'totalPages': 1,
            });
          }
          if (options.path == '/v1/deliveries/assigned-active') {
            return _json(<String, Object?>{
              'id': 'assigned-active',
              'requestId': 'request-for-assigned-active',
              'status': 'InTransit',
              'clientId': 'client-user-1',
              'jeeberId': 'jeeber-user-7',
              'pickupLocation': null,
              'dropoffLocation': null,
            });
          }
          if (options.path == '/v1/requests/request-for-assigned-active') {
            expect(options.headers['Authorization'], 'Bearer owner-read-token');
            return _json(<String, Object?>{
              'id': 'request-for-assigned-active',
              'status': 'InTransit',
              'clientId': 'client-user-1',
              'jeeberId': 'jeeber-user-7',
              'pickupLocation': <String, Object?>{
                'lat': 52.3994952,
                'lng': 5.2751205,
              },
              'dropoffLocation': <String, Object?>{
                'lat': 52.4002,
                'lng': 5.277,
              },
            });
          }
          return _json(<String, Object?>{}, status: 404);
        });
        final session = await gatewayOn(adapter).openSession(
          jeeberUserId: 'jeeber-user-7',
          roles: const <String>['customer', 'driver'],
        );

        final deliveries = await session.listDeliveries();
        final detail = await session.getDelivery(deliveries.single.id);

        expect(deliveries.single.id, 'assigned-active');
        expect(deliveries.single.jeeberUserId, 'jeeber-user-7');
        expect(detail.status, LocationSimulationDeliveryStatus.inTransit);
        expect(detail.pickupLocation.latitude, 52.3994952);
        expect(detail.dropoffLocation.longitude, 5.277);
        expect(adapter.requests.map((request) => request.path), <String>[
          '/v1/deliveries',
          '/v1/deliveries/assigned-active',
          '/v1/requests/request-for-assigned-active',
        ]);
        expect(
          adapter.requests.map((request) => request.path),
          isNot(contains('/v1/requests/assigned-active')),
        );
      },
    );

    test(
      'missing live coordinates stays an actionable blocking error',
      () async {
        when(
          () => tokenClient.mintTokenForUser(
            'client-user-1',
            roles: const <String>['customer'],
          ),
        ).thenAnswer((_) async => 'owner-read-token');
        final adapter = _ScriptedAdapter((options) {
          if (options.path == '/v1/deliveries/delivery-1') {
            return _json(<String, Object?>{
              'id': 'delivery-1',
              'requestId': 'request-without-coordinates',
              'status': 'InTransit',
              'clientId': 'client-user-1',
              'jeeberId': 'jeeber-user-7',
              'pickupLocation': null,
              'dropoffLocation': null,
            });
          }
          if (options.path == '/v1/requests/request-without-coordinates') {
            return _json(<String, Object?>{
              'id': 'request-without-coordinates',
              'status': 'heading_off',
              'clientId': 'client-user-1',
              'jeeberId': 'jeeber-user-7',
              'pickupLocation': null,
              'dropoffLocation': null,
            });
          }
          return _json(<String, Object?>{}, status: 404);
        });
        final session = await gatewayOn(adapter).openSession(
          jeeberUserId: 'jeeber-user-7',
          roles: const <String>['customer', 'driver'],
        );

        await expectLater(
          session.getDelivery('delivery-1'),
          throwsA(
            isA<LocationSimulationFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  LocationSimulationFailureKind.invalidResponse,
                )
                .having(
                  (failure) => failure.message,
                  'message',
                  allOf(
                    contains('no usable pickup/drop-off'),
                    contains('disposable'),
                  ),
                ),
          ),
        );
      },
    );

    test('refuses a roster identity without roles[] driver evidence', () async {
      final adapter = _ScriptedAdapter((_) => _json(const <String, Object?>{}));

      await expectLater(
        gatewayOn(adapter).openSession(
          jeeberUserId: 'customer-only',
          roles: const <String>['customer'],
        ),
        throwsA(
          isA<LocationSimulationFailure>().having(
            (failure) => failure.message,
            'message',
            contains('roles[]'),
          ),
        ),
      );
      verifyNever(
        () => tokenClient.mintTokenForUser(any(), roles: any(named: 'roles')),
      );
      expect(adapter.requests, isEmpty);
    });

    test(
      'maps token-mint failures into the simulator failure contract',
      () async {
        when(
          () => tokenClient.mintTokenForUser(any(), roles: any(named: 'roles')),
        ).thenThrow(
          const DevGatewayException(
            'forbidden',
            statusCode: 403,
            action: 'mint act-as token',
          ),
        );
        final adapter = _ScriptedAdapter(
          (_) => _json(const <String, Object?>{}),
        );

        await expectLater(
          gatewayOn(adapter).openSession(
            jeeberUserId: 'jeeber-user-7',
            roles: const <String>['customer', 'driver'],
          ),
          throwsA(
            isA<LocationSimulationFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  LocationSimulationFailureKind.authorization,
                )
                .having((failure) => failure.statusCode, 'statusCode', 403),
          ),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  });
}
