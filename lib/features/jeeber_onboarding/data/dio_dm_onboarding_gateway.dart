import 'package:dio/dio.dart';

import '../domain/dm_onboarding_gateway.dart';

class DioDmOnboardingGateway implements DmOnboardingGateway {
  const DioDmOnboardingGateway(Dio _);

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {}
}
