import 'package:dio/dio.dart';

import '../domain/display_name_repository.dart';

/// Dio-backed [DisplayNameRepository].
///
/// Endpoint (gateway contract, cycle-2 a99c66a):
///   PUT /api/User/profile   body: `{ "username": "<display name>" }`
///
/// The gateway mirrors `username` into the users projection, so the very next
/// `GET /v1/users/me` (getMe) surfaces the saved name and every downstream
/// jeeberName consumer (receipts / chat headers / pushes) picks it up. The
/// path is the RAW gateway shape — same family as the super-login
/// `/api/User/*` endpoints (`super_login_service.dart`); do NOT prefix a
/// `:4010` service segment here (live-gateway contract, not the Express mock).
class DioDisplayNameRepository implements DisplayNameRepository {
  const DioDisplayNameRepository(this._dio);

  final Dio _dio;

  /// Gateway-contract path (see class doc).
  static const String path = '/api/User/profile';

  @override
  Future<void> submitDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      // Nothing to submit — an empty name must never blank the projection.
      return;
    }
    try {
      await _dio.put<Map<String, dynamic>>(
        path,
        data: <String, dynamic>{'username': trimmed},
      );
    } on DioException catch (e) {
      throw DisplayNameRepositoryException(_map(e), e.message);
    }
  }

  DisplayNameFailure _map(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) return DisplayNameFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return DisplayNameFailure.network;
      default:
        return DisplayNameFailure.unknown;
    }
  }
}
