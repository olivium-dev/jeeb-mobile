import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../domain/display_name_repository.dart';

class DioDisplayNameRepository implements DisplayNameRepository {
  const DioDisplayNameRepository(this._dio);

  final Dio _dio;

  static const String path = '/api/User/profile';

  static const String _mePath = '/v1/users/me';

  @override
  Future<void> submitDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final me = await _dio.get<Map<String, dynamic>>(_mePath);
      final json = me.data ?? const <String, dynamic>{};
      final userId = _str(json['userId'] ?? json['user_id'] ?? json['id']);
      final email = _str(json['email']);
      // F5 fix: was hardcoded `profilePic: ''` (which IS serialized and wiped
      // the avatar); read-and-preserve `/v1/users/me`'s value instead.
      final avatarUrl = _str(
        json['avatarUrl'] ?? json['avatar_url'] ?? json['photoUrl'],
      );
      // UX-23: a partial `/v1/users/me` used to be PUT back as `''`, blanking
      // the stored identity. An unresolved field is omitted, never emptied.
      if (userId == null) {
        throw const DisplayNameRepositoryException(
          DisplayNameFailure.unauthorized,
        );
      }
      await _dio.put<Map<String, dynamic>>(
        path,
        data: <String, dynamic>{
          'userId': userId,
          'email': ?email,
          'username': trimmed,
          'profilePic': ?avatarUrl,
        },
      );
    } on DioException catch (e) {
      throw DisplayNameRepositoryException(_map(e), e.message);
    }
  }

  String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DisplayNameFailure _map(DioException e) => switch (AppFailure.of(e).kind) {
    AppFailureKind.unauthorized ||
    AppFailureKind.forbidden => DisplayNameFailure.unauthorized,
    AppFailureKind.network ||
    AppFailureKind.timeout => DisplayNameFailure.network,
    AppFailureKind.server => DisplayNameFailure.serverError,
    _ => DisplayNameFailure.unknown,
  };
}
