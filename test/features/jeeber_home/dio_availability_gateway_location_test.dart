import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';
import 'package:jeeb_mobile/features/jeeber_home/data/dio_availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';

/// Stub Dio that records every PATCH body (the live-lane go-online path).
class _FakeDio extends Fake implements Dio {
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>?> bodies = <Map<String, dynamic>?>[];

  String? get lastPath => paths.isEmpty ? null : paths.last;
  Map<String, dynamic>? get lastData => bodies.isEmpty ? null : bodies.last;
  int get patchCount => paths.length;

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    paths.add(path);
    bodies.add(data as Map<String, dynamic>?);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{'available': true} as T,
    );
  }
}

GpsSample _sample(double lat, double lng) => GpsSample(
      latitude: lat,
      longitude: lng,
      accuracyMeters: 5,
      speedMps: 0,
      headingDegrees: 0,
      capturedAt: DateTime(2026, 1, 1),
    );

void main() {
  // Coordinates only ride the LIVE-lane PATCH. In mock-prefix builds toggle()
  const Object skipReason = MockGatewayClient.useMockPrefixes
      ? 'coordinates are only sent in the live lane'
      : false;

  group('DioAvailabilityGateway go-online location fix (JEBV4-211 / E16)', () {
    test('sends the injected REAL device fix — never the hardcoded Damascus',
        () async {
      final dio = _FakeDio();
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async => _sample(1.2345, 4.5678),
      );

      final result = await sut.toggle(goOnline: true);

      expect(dio.lastData?['online'], true);
      expect(dio.lastData?['latitude'], 1.2345);
      expect(dio.lastData?['longitude'], 4.5678);
      expect(result.location, GoOnlineLocationOutcome.attached);
      // Regression guard: the old hardcoded fallback must be gone.
      expect(dio.lastData?['latitude'], isNot(33.5138));
      expect(dio.lastData?['longitude'], isNot(36.2765));
    }, skip: skipReason);

    test('D2: a hard fix failure still goes online but reports fixFailed',
        () async {
      final dio = _FakeDio();
      var calls = 0;
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async {
          calls++;
          throw StateError('no fix');
        },
        lastKnownFix: () async => null,
      );

      final result = await sut.toggle(goOnline: true);

      expect(dio.lastData?['online'], true);
      expect(dio.lastData?.containsKey('latitude'), false);
      expect(dio.lastData?.containsKey('longitude'), false);
      expect(result.location, GoOnlineLocationOutcome.fixFailed);
      // Retried exactly once before giving up.
      expect(calls, 2);
    }, skip: skipReason);

    test('D2: retries a transient fix failure and attaches the second fix',
        () async {
      final dio = _FakeDio();
      var calls = 0;
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async {
          calls++;
          if (calls == 1) throw StateError('transient');
          return _sample(33.1, 35.5);
        },
      );

      final result = await sut.toggle(goOnline: true);

      expect(calls, 2);
      expect(dio.lastData?['latitude'], 33.1);
      expect(dio.lastData?['longitude'], 35.5);
      expect(result.location, GoOnlineLocationOutcome.attached);
    }, skip: skipReason);

    test('D2: a denied permission short-circuits without a retry', () async {
      final dio = _FakeDio();
      var calls = 0;
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async {
          calls++;
          throw const LocationCaptureDeniedException();
        },
        lastKnownFix: () async => _sample(1, 1),
      );

      final result = await sut.toggle(goOnline: true);

      expect(calls, 1);
      expect(result.location, GoOnlineLocationOutcome.permissionDenied);
      expect(dio.lastData?['online'], true);
      expect(dio.lastData?.containsKey('latitude'), false);
    }, skip: skipReason);

    test('D2: falls back to the cached OS fix when the live fix fails',
        () async {
      final dio = _FakeDio();
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async => throw StateError('no fix'),
        lastKnownFix: () async => _sample(34.4, 36.6),
      );

      final result = await sut.toggle(goOnline: true);

      expect(dio.lastData?['latitude'], 34.4);
      expect(dio.lastData?['longitude'], 36.6);
      expect(result.location, GoOnlineLocationOutcome.attached);
    }, skip: skipReason);

    test('degrades to NO coordinates when no location seam is injected',
        () async {
      final dio = _FakeDio();
      final sut = DioAvailabilityGateway(dio);

      final result = await sut.toggle(goOnline: true);

      expect(dio.lastData?['online'], true);
      expect(dio.lastData?.containsKey('latitude'), false);
      expect(result.location, GoOnlineLocationOutcome.notApplicable);
    }, skip: skipReason);

    test('go-offline reports notApplicable and never captures a fix', () async {
      final dio = _FakeDio();
      var calls = 0;
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async {
          calls++;
          return _sample(1, 1);
        },
      );

      final result = await sut.toggle(goOnline: false);

      expect(calls, 0);
      expect(dio.lastData, <String, dynamic>{'online': false});
      expect(result.location, GoOnlineLocationOutcome.notApplicable);
    }, skip: skipReason);
  });

  group('DioAvailabilityGateway.refreshLocation (D2 idle-online refresh)', () {
    test('re-stamps last_location with the constants go-online already sends',
        () async {
      final dio = _FakeDio();
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async => _sample(33.88, 35.49),
      );

      final outcome = await sut.refreshLocation();

      expect(outcome, GoOnlineLocationOutcome.attached);
      expect(dio.patchCount, 1);
      expect(dio.lastPath, '/jeebers/me/availability');
      expect(dio.lastData, <String, dynamic>{
        'online': true,
        'vehicleType': 'car',
        'zone': 'default',
        'latitude': 33.88,
        'longitude': 35.49,
      });
    }, skip: skipReason);

    test('makes NO network call when the fix fails (never clobbers state)',
        () async {
      final dio = _FakeDio();
      var calls = 0;
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async {
          calls++;
          throw StateError('no fix');
        },
      );

      final outcome = await sut.refreshLocation();

      expect(outcome, GoOnlineLocationOutcome.fixFailed);
      expect(dio.patchCount, 0);
      // Resume refresh is single-shot: no retry storm on foreground.
      expect(calls, 1);
    }, skip: skipReason);
  });
}
