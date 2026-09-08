import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
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
        throw OtpHandoverException(OtpHandoverErrorKind.parse, response);
      }
      final code = data['code'] as String?;
      if (code != null && code.isNotEmpty) {
        return OtpFetchResult(
          code: code,
          smsTriggered: data['triggered'] == true,
        );
      }
      if (data['triggered'] == true) {
        return const OtpFetchResult(smsTriggered: true);
      }
      throw OtpHandoverException(OtpHandoverErrorKind.parse, response);
    } on DioException catch (e) {
      throw _map(e, onVerify: false);
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
      // A 200 that says `verified:false` is a REFUSED handover, not a success
      // with a flag: it must land on the same branch as a 401.
      if (data['verified'] != true) {
        throw const OtpHandoverException(OtpHandoverErrorKind.invalidOtp);
      }
      return const OtpHandoverResult(success: true);
    } on DioException catch (e) {
      throw _map(e, onVerify: true);
    }
  }

  /// The one classification point: RFC 7807 `type` first, then status, then
  /// the shared transport classification. Server prose is never carried.
  OtpHandoverException _map(DioException e, {required bool onVerify}) {
    final GatewayProblem? problem = GatewayProblem.tryParse(e.response?.data);
    final int? status = e.response?.statusCode;
    final String? suffix = problem?.typeSuffix;

    if (status == 423) {
      return OtpHandoverLocked(
        escalationId: problem?.escalationId,
        lockedAt: problem?.lockedAt,
        attemptsRemaining: problem?.attemptsRemaining,
        cause: e,
      );
    }
    switch (suffix) {
      case 'not-at-door':
        return OtpHandoverException(OtpHandoverErrorKind.notAtDoor, e);
      case 'handover-wrong-party':
        return OtpHandoverException(OtpHandoverErrorKind.wrongParty, e);
    }
    // Only a VERIFY 401 means "wrong code"; on the GET it is an expired
    // session, which must not read as an invalid code.
    if (status == 401 && onVerify) {
      return OtpHandoverException(
        OtpHandoverErrorKind.invalidOtp,
        e,
        problem?.attemptsRemaining,
      );
    }
    if (status == 401) {
      return OtpHandoverException(OtpHandoverErrorKind.unauthorized, e);
    }
    if (status == 404) {
      return OtpHandoverException(OtpHandoverErrorKind.notFound, e);
    }

    final AppFailure failure = AppFailure.of(e);
    return switch (failure.kind) {
      AppFailureKind.network || AppFailureKind.timeout => OtpHandoverException(
          OtpHandoverErrorKind.network,
          e,
        ),
      AppFailureKind.notFound => OtpHandoverException(
          OtpHandoverErrorKind.notFound,
          e,
        ),
      AppFailureKind.unauthorized => OtpHandoverException(
          OtpHandoverErrorKind.unauthorized,
          e,
        ),
      AppFailureKind.rateLimited => OtpHandoverException(
          OtpHandoverErrorKind.server,
          failure,
        ),
      _ => OtpHandoverException(OtpHandoverErrorKind.server, e),
    };
  }
}
