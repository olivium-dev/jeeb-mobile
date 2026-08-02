import 'package:dio/dio.dart';

import '../domain/cancel_request_repository.dart';

class DioCancelRequestRepository implements CancelRequestRepository {
  const DioCancelRequestRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> cancelRequest({required String requestId}) async {
    try {
      await _dio.delete<dynamic>(
        '/v1/requests/${Uri.encodeComponent(requestId)}',
      );
    } on DioException catch (e) {
      throw CancelRequestException(_classify(e), e.message);
    }
  }

  static CancelRequestFailure _classify(DioException e) {
    switch (e.response?.statusCode) {
      case 409:
        return CancelRequestFailure.conflict;
      case 404:
        return CancelRequestFailure.notFound;
      case 403:
        return CancelRequestFailure.forbidden;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return CancelRequestFailure.network;
      default:
        return CancelRequestFailure.unknown;
    }
  }
}
