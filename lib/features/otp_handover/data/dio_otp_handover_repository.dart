import 'package:dio/dio.dart';

import '../domain/otp_handover_repository.dart';
import '../domain/otp_handover_result.dart';

/// T-MOB-018: Endpoint contract verified against Mockoon :3055
/// (d5-delivery-lifecycle suite, scenario s09-live-tracking).
///
/// GET  /v1/deliveries/{id}/otp
///   → OtpStatusDto { deliveryId, triggered, code, expiresAt, attemptsRemaining }
///   (wave-11 alias; `code` is the 4-digit string the client displays)
///
/// POST /v1/deliveries/{id}/otp/verify
///   body: { code: "1234" }
///   → OtpHandoverVerificationResponse { deliveryId, verified, status, message }
///   200 = success; 401 = wrong code; 423 = locked (3 attempts exhausted)
///
/// S7: both paths use the `/v1/deliveries` prefix so the single
/// `MockGatewayClient` rewrite key (`/v1/deliveries` →
/// `/delivery-service/v1/deliveries`) catches them. The verify path previously
/// used an un-versioned `/deliveries` that is NOT a rewrite key, so it bypassed
/// the rewrite and 404'd against the Express mock on :4010.
class DioOtpHandoverRepository implements OtpHandoverRepository {
  DioOtpHandoverRepository(this._dio);

  final Dio _dio;

  // GET  /v1/deliveries/{id}/otp        → returns code for client display
  // POST /v1/deliveries/{id}/otp/verify → Jeeber submits the code
  static const _v1DeliveriesPath = '/v1/deliveries';

  @override
  Future<String> fetchHandoverCode({required String deliveryId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_v1DeliveriesPath/$deliveryId/otp',
      );
      final data = response.data;
      if (data == null) {
        throw const OtpHandoverException(OtpHandoverErrorKind.parse);
      }
      // OtpStatusDto: `code` field added in wave-11 contract addendum
      final code = data['code'] as String?;
      if (code == null || code.isEmpty) {
        throw const OtpHandoverException(OtpHandoverErrorKind.parse);
      }
      return code;
    } on DioException catch (e) {
      throw OtpHandoverException(_mapDioKind(e), e);
    }
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_v1DeliveriesPath/$deliveryId/otp/verify',
        data: {'code': otp},
      );
      final data = response.data ?? {};
      final verified = data['verified'] as bool? ?? false;
      return OtpHandoverResult(
        success: verified,
        message: data['message'] as String?,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw const OtpHandoverException(OtpHandoverErrorKind.invalidOtp);
      }
      if (status == 423) {
        throw const OtpHandoverException(OtpHandoverErrorKind.locked);
      }
      throw OtpHandoverException(_mapDioKind(e), e);
    }
  }

  OtpHandoverErrorKind _mapDioKind(DioException e) =>
      e.response == null ? OtpHandoverErrorKind.network : OtpHandoverErrorKind.server;
}
