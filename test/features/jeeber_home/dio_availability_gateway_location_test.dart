import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';
import 'package:jeeb_mobile/features/jeeber_home/data/dio_availability_gateway.dart';

/// Stub Dio that records the last PATCH body (the live-lane go-online path).
class _FakeDio extends Fake implements Dio {
  String? lastPath;
  Map<String, dynamic>? lastData;

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
    lastPath = path;
    lastData = data as Map<String, dynamic>?;
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
  // POSTs {userId, available} with no geo, so these assertions don't apply.
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

      await sut.toggle(goOnline: true);

      expect(dio.lastData?['online'], true);
      expect(dio.lastData?['latitude'], 1.2345);
      expect(dio.lastData?['longitude'], 4.5678);
      // Regression guard: the old hardcoded fallback must be gone.
      expect(dio.lastData?['latitude'], isNot(33.5138));
      expect(dio.lastData?['longitude'], isNot(36.2765));
    }, skip: skipReason);

    test('degrades to NO coordinates when the fix throws (permission denied)',
        () async {
      final dio = _FakeDio();
      final sut = DioAvailabilityGateway(
        dio,
        locationFix: () async => throw StateError('denied'),
      );

      await sut.toggle(goOnline: true);

      expect(dio.lastData?['online'], true);
      expect(dio.lastData?.containsKey('latitude'), false);
      expect(dio.lastData?.containsKey('longitude'), false);
    }, skip: skipReason);

    test('degrades to NO coordinates when no location seam is injected',
        () async {
      final dio = _FakeDio();
      final sut = DioAvailabilityGateway(dio);

      await sut.toggle(goOnline: true);

      expect(dio.lastData?['online'], true);
      expect(dio.lastData?.containsKey('latitude'), false);
    }, skip: skipReason);
  });
}
