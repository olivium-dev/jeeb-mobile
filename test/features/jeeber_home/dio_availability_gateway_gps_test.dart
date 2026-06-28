// SPRINT-003 — GO ONLINE must carry real GPS coordinates.
//
// Delivery-service `ListOnline` filters `last_lat/last_lng IS NOT NULL`, so a
// jeeber that toggles online with null coordinates is dropped from the online
// roster and can never be matched (`online_total:0`). These tests lock the
// contract: the PATCH GO ONLINE body now carries the latitude/longitude from a
// resolved device fix, and degrades gracefully (to the injected coords, or
// null) when no fix is available — never failing the toggle.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_home/data/dio_availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/online_location_fix.dart';

/// Captures the outbound request body and replies with a 200 online response.
class _BodyCapture {
  Map<String, dynamic>? lastBody;

  Dio dio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          lastBody = options.data as Map<String, dynamic>?;
          handler.resolve(
            Response(
              data: <String, dynamic>{'online': true, 'activeDeliveries': 0},
              statusCode: 200,
              requestOptions: options,
            ),
          );
        },
      ),
    );
    return dio;
  }
}

/// Returns a fixed fix, or null to simulate an unavailable fix.
class _FakeFix implements OnlineLocationFix {
  const _FakeFix(this._coords);
  final OnlineCoordinates? _coords;
  @override
  Future<OnlineCoordinates?> resolve() async => _coords;
}

/// Throws — proves a location fault never fails the toggle.
class _ThrowingFix implements OnlineLocationFix {
  const _ThrowingFix();
  @override
  Future<OnlineCoordinates?> resolve() async => throw Exception('gps boom');
}

void main() {
  group('DioAvailabilityGateway — GO ONLINE carries GPS coords', () {
    test('attaches latitude/longitude from the resolved device fix', () async {
      final capture = _BodyCapture();
      final gateway = DioAvailabilityGateway(
        capture.dio(),
        locationFix: const _FakeFix(
          OnlineCoordinates(latitude: 33.8886, longitude: 35.4955),
        ),
      );

      await gateway.toggle(goOnline: true);

      expect(capture.lastBody?['online'], true);
      expect(capture.lastBody?['vehicleType'], 'car');
      expect(capture.lastBody?['zone'], 'default');
      expect(capture.lastBody?['latitude'], 33.8886);
      expect(capture.lastBody?['longitude'], 35.4955);
    });

    test('falls back to injected coords when the fix resolves null', () async {
      final capture = _BodyCapture();
      final gateway = DioAvailabilityGateway(
        capture.dio(),
        latitude: 34.0,
        longitude: 36.0,
        locationFix: const _FakeFix(null),
      );

      await gateway.toggle(goOnline: true);

      expect(capture.lastBody?['latitude'], 34.0);
      expect(capture.lastBody?['longitude'], 36.0);
    });

    test('a location fault degrades to injected coords, never throws',
        () async {
      final capture = _BodyCapture();
      final gateway = DioAvailabilityGateway(
        capture.dio(),
        latitude: 31.5,
        longitude: 34.5,
        locationFix: const _ThrowingFix(),
      );

      await gateway.toggle(goOnline: true);

      expect(capture.lastBody?['latitude'], 31.5);
      expect(capture.lastBody?['longitude'], 34.5);
    });

    test('GO OFFLINE body stays minimal and reads no GPS', () async {
      final capture = _BodyCapture();
      final gateway = DioAvailabilityGateway(
        capture.dio(),
        locationFix: const _ThrowingFix(),
      );

      await gateway.toggle(goOnline: false);

      expect(capture.lastBody, <String, dynamic>{'online': false});
    });
  });
}
