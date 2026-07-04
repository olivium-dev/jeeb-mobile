import 'package:dio/dio.dart';

import '../domain/dm_onboarding_gateway.dart';

/// Dio-backed [DmOnboardingGateway] (JM-038).
///
/// Confirms the chosen home base is serviceable before the wizard chains on to
/// KYC identity. Speaks the gateway-contract path (the `MockGatewayClient`
/// interceptor rewrites `/v1/matching` → `/matching/v1/matching` at :4010):
///
///   POST /v1/matching/find-jeebers
///     { origin:{lat,lng}, tier, requestId } → { count, jeeberIds, radiusMeters }
///
/// The matching endpoint requires `origin` + `tier`; we send the pinned home
/// base as the origin and a reachable default tier so the coverage probe 200s.
/// A non-2xx (e.g. a malformed home base the mock rejects) throws so the cubit
/// surfaces `submitFailed` and keeps the Jeeber on the service-area step rather
/// than chaining to KYC against an unserviceable base.
///
/// JEBV4-111: `/v1/matching/find-jeebers` is served by NO deployed gateway
/// (the live BFF's MatchingController exposes only `POST /matching/run` +
/// `GET /matching/users/{id}`), so a route-level 404 here means "the coverage
/// probe endpoint does not exist in this environment", NOT "this home base is
/// unserviceable". Blocking every Jeeber forever on a missing optional probe
/// dead-ends the whole become-a-jeeber flow before the KYC wizard. The probe
/// is therefore BEST-EFFORT on 404 (the same convention as the find-jeebers
/// call in `chat/data/dio_order_broadcast_service.dart`): coverage unknown →
/// proceed to KYC. Any other non-2xx (400/422 rejection, 5xx) still throws so
/// the cubit surfaces `submitFailed`.
class DioDmOnboardingGateway implements DmOnboardingGateway {
  const DioDmOnboardingGateway(this._dio);

  final Dio _dio;

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/matching/find-jeebers',
        data: <String, Object?>{
          // The Jeeber's pinned home base is the coverage origin (D51).
          'origin': <String, Object?>{
            'lat': submission.homeBaseLat,
            'lng': submission.homeBaseLng,
          },
          // Matching requires a tier band; onboarding has no order tier yet, so
          // probe with a reachable default purely to validate coverage.
          'tier': 'express',
          // Onboarding coverage probe — not tied to a real request.
          'requestId': 'jeeber-onboarding-home-base',
        },
      );
    } on DioException catch (e) {
      // Route not deployed → coverage unknown, non-blocking (JEBV4-111).
      if (e.response?.statusCode == 404) return;
      rethrow;
    }
  }
}
