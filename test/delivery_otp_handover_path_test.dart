// S7 — dropoff OTP handover endpoint contract.
//
// The defining piece of the delivery-lifecycle step is the door-OTP handover.
// Both repositories must speak the `/v1/deliveries/{id}/otp[/verify]` paths so
// the single `MockGatewayClient` rewrite key (`/v1/deliveries` →
// `/delivery-service/v1/deliveries`) catches them. The verify path previously
// used an un-versioned `/deliveries` that is NOT a rewrite key, so it bypassed
// the rewrite and 404'd against the Express mock. These tests pin the paths so
// the regression can't silently come back.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/otp_handover/data/dio_otp_handover_repository.dart';

/// Records every GET/POST path + body, returns scripted responses.
class _RecordingDio extends Fake implements Dio {
  final List<String> getPaths = [];
  final List<String> postPaths = [];
  Map<String, dynamic>? lastPostData;

  Map<String, dynamic> nextGetData = const {};
  Map<String, dynamic> nextPostData = const {};

  Response<T> _resp<T>(String path, Object? data) => Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: data as T,
      );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getPaths.add(path);
    return _resp<T>(path, nextGetData);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postPaths.add(path);
    lastPostData = data as Map<String, dynamic>?;
    return _resp<T>(path, nextPostData);
  }
}

void main() {
  group('DioOtpHandoverRepository — /v1/deliveries contract', () {
    test('fetchHandoverCode GETs /v1/deliveries/{id}/otp', () async {
      final dio = _RecordingDio()..nextGetData = {'code': '1234'};
      final repo = DioOtpHandoverRepository(dio);

      final code = await repo.fetchHandoverCode(deliveryId: 'delivery-005');

      expect(code, '1234');
      expect(dio.getPaths, ['/v1/deliveries/delivery-005/otp']);
    });

    test('submitOtp POSTs /v1/deliveries/{id}/otp/verify (rewrite-catchable)',
        () async {
      final dio = _RecordingDio()..nextPostData = {'verified': true};
      final repo = DioOtpHandoverRepository(dio);

      final result = await repo.submitOtp(deliveryId: 'delivery-005', otp: '1234');

      expect(result.success, isTrue);
      expect(dio.postPaths, ['/v1/deliveries/delivery-005/otp/verify']);
      expect(dio.postPaths.single, startsWith('/v1/deliveries'));
      expect(dio.lastPostData?['code'], '1234');
    });
  });

  group('DioActiveDeliveryRepository.verifyDoorOtp — /v1/deliveries contract',
      () {
    test('issues then verifies, both under /v1/deliveries, flips to Done',
        () async {
      final dio = _RecordingDio()
        ..nextGetData = {'code': '1234'}
        ..nextPostData = {'verified': true, 'status': 'Done'};
      final repo = DioActiveDeliveryRepository(dio);

      final status =
          await repo.verifyDoorOtp(deliveryId: 'delivery-005', code: '1234');

      expect(status, JeeberDeliveryStatus.done);
      // Issue-on-demand GET uses the versioned path.
      expect(dio.getPaths, ['/v1/deliveries/delivery-005/otp']);
      // Verify POST uses the versioned path so the rewrite key catches it.
      expect(dio.postPaths, ['/v1/deliveries/delivery-005/otp/verify']);
      expect(dio.postPaths.single, startsWith('/v1/deliveries'));
      expect(dio.lastPostData?['code'], '1234');
    });
  });
}
