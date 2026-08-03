import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';

/// JEBV4-111 regression — the JM-038 coverage probe endpoint
/// `/v1/matching/find-jeebers` is not served by any deployed gateway, so a

const _submission = DmOnboardingSubmission(
  state: 'Mount Lebanon',
  country: 'Lebanon',
  street: 'Main St',
  address: 'Bldg 4',
  homeBaseLat: 33.8938,
  homeBaseLng: 35.5018,
  homeBaseLabel: 'Beirut',
);

Dio _dio({
  int? respondStatus,
  Object? body,
  int? rejectStatus,
  DioExceptionType rejectType = DioExceptionType.badResponse,
  void Function(RequestOptions)? onRequest,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        if (rejectStatus != null || rejectType != DioExceptionType.badResponse) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: rejectType,
              response: rejectStatus != null
                  ? Response(
                      data: null,
                      statusCode: rejectStatus,
                      requestOptions: options,
                    )
                  : null,
            ),
          );
          return;
        }
        handler.resolve(
          Response(
            data: body ?? <String, dynamic>{'count': 3},
            statusCode: respondStatus ?? 200,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DioDmOnboardingGateway — JM-038 coverage probe (JEBV4-111)', () {
    test('posts the pinned home base to /v1/matching/find-jeebers', () async {
      late RequestOptions captured;
      final gateway = DioDmOnboardingGateway(
        _dio(onRequest: (o) => captured = o),
      );
      await gateway.submit(_submission);
      expect(captured.method, 'POST');
      expect(captured.path, '/v1/matching/find-jeebers');
      final data = captured.data as Map<String, Object?>;
      expect(data['origin'], {'lat': 33.8938, 'lng': 35.5018});
      expect(data['tier'], 'express');
    });

    test('a 2xx coverage confirmation completes normally', () async {
      final gateway = DioDmOnboardingGateway(_dio(respondStatus: 200));
      await expectLater(gateway.submit(_submission), completes);
    });

    test(
        'route-level 404 (probe endpoint not deployed) is BEST-EFFORT: '
        'completes so the wizard chains to KYC instead of dead-ending',
        () async {
      final gateway = DioDmOnboardingGateway(_dio(rejectStatus: 404));
      await expectLater(gateway.submit(_submission), completes);
    });

    test('a 400 rejection still throws so the cubit surfaces submitFailed',
        () async {
      final gateway = DioDmOnboardingGateway(_dio(rejectStatus: 400));
      await expectLater(
        gateway.submit(_submission),
        throwsA(isA<DioException>()),
      );
    });

    test('a 503 outage still throws so the cubit surfaces submitFailed',
        () async {
      final gateway = DioDmOnboardingGateway(_dio(rejectStatus: 503));
      await expectLater(
        gateway.submit(_submission),
        throwsA(isA<DioException>()),
      );
    });

    test('a connection error (no response) still throws', () async {
      final gateway = DioDmOnboardingGateway(
        _dio(rejectType: DioExceptionType.connectionError),
      );
      await expectLater(
        gateway.submit(_submission),
        throwsA(isA<DioException>()),
      );
    });
  });
}
