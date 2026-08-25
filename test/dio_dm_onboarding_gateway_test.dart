import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';

const _submission = DmOnboardingSubmission(
  state: 'Mount Lebanon',
  country: 'Lebanon',
  street: 'Main St',
  address: 'Bldg 4',
  homeBaseLat: 33.8938,
  homeBaseLng: 35.5018,
  homeBaseLabel: 'Beirut',
);

void main() {
  test(
    'onboarding advances locally without sending precise coordinates',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );

      await expectLater(
        DioDmOnboardingGateway(dio).submit(_submission),
        completes,
      );
      expect(requests, isEmpty);
    },
  );
}
