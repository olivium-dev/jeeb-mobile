import 'package:dio/dio.dart';

import '../domain/display_name_repository.dart';

/// Dio-backed [DisplayNameRepository].
///
/// Endpoint (gateway contract, cycle-2 a99c66a; cycle-6 400 fix):
///   PUT /api/User/profile
///     body: `{ "userId", "email", "username", "profilePic" }`
///
/// The gateway→user-management contract REQUIRES all four fields (`profilePic`
/// may be `''`); omitting any → HTTP 400 ("We couldn't save your name" on
/// device). `userId` + `email` are sourced from the authenticated identity via
/// `GET /v1/users/me` (getMe) on the same Dio, mirroring
/// `dio_customer_profile_repository.dart`.
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

  /// getMe path — identity source for the required `userId`/`email` fields.
  /// Same live-gateway shape as `dio_customer_profile_repository.dart`.
  static const String _mePath = '/v1/users/me';

  @override
  Future<void> submitDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      // Nothing to submit — an empty name must never blank the projection.
      return;
    }
    try {
      // The PUT contract requires userId + email; fetch them from the current
      // authenticated identity (getMe) on the same authenticated Dio.
      final me = await _dio.get<Map<String, dynamic>>(_mePath);
      final json = me.data ?? const <String, dynamic>{};
      final userId = _str(json['userId'] ?? json['user_id'] ?? json['id']);
      final email = _str(json['email']);
      await _dio.put<Map<String, dynamic>>(
        path,
        data: <String, dynamic>{
          'userId': userId ?? '',
          'email': email ?? '',
          'username': trimmed,
          'profilePic': '',
        },
      );
    } on DioException catch (e) {
      throw DisplayNameRepositoryException(_map(e), e.message);
    }
  }

  /// Normalise a JSON value to a non-empty trimmed `String`, else `null`.
  String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
