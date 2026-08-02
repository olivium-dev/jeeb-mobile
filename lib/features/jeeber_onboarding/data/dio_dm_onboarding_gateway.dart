import 'package:dio/dio.dart';

import '../domain/dm_onboarding_gateway.dart';

class DioDmOnboardingGateway implements DmOnboardingGateway {
  const DioDmOnboardingGateway(this._dio);

  final Dio _dio;

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/matching/find-jeebers',
        data: <String, Object?>{
          'origin': <String, Object?>{
            'lat': submission.homeBaseLat,
            'lng': submission.homeBaseLng,
          },
          'tier': 'express',
          'requestId': 'jeeber-onboarding-home-base',
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      rethrow;
    }
  }
}
