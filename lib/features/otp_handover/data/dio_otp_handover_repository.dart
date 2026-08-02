import 'package:dio/dio.dart';

import '../domain/otp_handover_repository.dart';
import '../domain/otp_handover_result.dart';

class DioOtpHandoverRepository implements OtpHandoverRepository {
  DioOtpHandoverRepository(this._dio);

  final Dio _dio;

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
