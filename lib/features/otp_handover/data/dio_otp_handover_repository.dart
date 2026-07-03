import 'package:dio/dio.dart';

import '../domain/otp_handover_repository.dart';
import '../domain/otp_handover_result.dart';

/// T-MOB-018: Endpoint contract verified against Mockoon :3055
/// (d5-delivery-lifecycle suite, scenario s09-live-tracking).
///
/// GET  /v1/deliveries/{id}/otp
///   → OtpStatusDto { deliveryId, triggered, code, expiresAt, attemptsRemaining }
///   (wave-11 alias; `code` is the 4-digit string the client displays)
///   G4: the LIVE gateway returns `{ deliveryId, triggered: true, message }` —
///   NO `code`; the call is an SMS trigger to the recipient (run-23 wire,
///   `proof-run23/wire/customer-otp-fetch-redacted.txt`). Mapped to
///   `OtpFetchResult.smsTriggered` rather than a parse error.
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
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_v1DeliveriesPath/$deliveryId/otp',
      );
      final data = response.data;
      if (data == null) {
        throw const OtpHandoverException(OtpHandoverErrorKind.parse);
      }
      // Two legitimate wire shapes (G4):
      //  • mock / wave-11 addendum: `{ …, code: "1234" }` → in-app display.
      //  • LIVE gateway (run-23):   `{ deliveryId, triggered: true, message }`
      //    → the endpoint SMS-triggered the code to the recipient; there is
      //    nothing to display in-app. Surfaced as `smsTriggered` instead of
      //    the pre-fix `parse` throw (which flipped the customer to a
      //    code-ENTRY grid for a code they were never shown).
      final code = data['code'] as String?;
      if (code != null && code.isNotEmpty) {
        return OtpFetchResult(code: code, smsTriggered: data['triggered'] == true);
      }
      if (data['triggered'] == true) {
        return const OtpFetchResult(smsTriggered: true);
      }
      throw const OtpHandoverException(OtpHandoverErrorKind.parse);
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
