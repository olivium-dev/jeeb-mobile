import 'package:dio/dio.dart';

import '../domain/otp_handover_repository.dart';
import '../domain/otp_handover_result.dart';

class DioOtpHandoverRepository implements OtpHandoverRepository {
  DioOtpHandoverRepository(this._dio);

  final Dio _dio;

  static const _deliveryPath = '/v1/delivery';
  static const _transitionPath = '/v1/delivery/status/transition';

  @override
  Future<String> fetchHandoverCode({required String deliveryId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_deliveryPath/$deliveryId',
      );
      final data = response.data;
      if (data == null) {
        throw const OtpHandoverException(OtpHandoverErrorKind.parse);
      }
      final code = data['handoverCode'] as String?;
      if (code == null || code.isEmpty) {
        throw const OtpHandoverException(OtpHandoverErrorKind.parse);
      }
      return code;
    } on DioException catch (e) {
      throw OtpHandoverException(
        e.response == null
            ? OtpHandoverErrorKind.network
            : OtpHandoverErrorKind.server,
        e,
      );
    }
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _transitionPath,
        data: {
          'deliveryId': deliveryId,
          'to': 'Delivered',
          'handoverCode': otp,
        },
      );
      final data = response.data;
      return OtpHandoverResult(
        success: true,
        message: data?['message'] as String?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 422 || e.response?.statusCode == 400) {
        throw const OtpHandoverException(OtpHandoverErrorKind.invalidOtp);
      }
      throw OtpHandoverException(
        e.response == null
            ? OtpHandoverErrorKind.network
            : OtpHandoverErrorKind.server,
        e,
      );
    }
  }
}
